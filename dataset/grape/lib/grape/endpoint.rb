module Grape
  class Endpoint
    include Grape::DSL::Settings

    attr_accessor :block, :source, :options
    attr_reader :env, :request, :headers, :params

    include Grape::DSL::InsideRoute

    class << self
      def before_each(new_setup = false, &block)
        if new_setup == false
          if block_given?
            @before_each = block
          else
            return @before_each
          end
        else
          @before_each = new_setup
        end
      end

      def generate_api_method(method_name, &block)
        if instance_methods.include?(method_name.to_sym) || instance_methods.include?(method_name.to_s)
          fail NameError.new("method #{method_name.inspect} already exists and cannot be used as an unbound method name")
        end

        #nodyna <define_method-2826> <DM COMPLEX (event)>
        define_method(method_name, &block)
        method = instance_method(method_name)
        remove_method(method_name)

        proc do |endpoint_instance|
          ActiveSupport::Notifications.instrument('endpoint_render.grape', endpoint: endpoint_instance) do
            method.bind(endpoint_instance).call
          end
        end
      end
    end

    def initialize(new_settings, options = {}, &block)
      require_option(options, :path)
      require_option(options, :method)

      self.inheritable_setting = new_settings.point_in_time_copy

      route_setting(:saved_declared_params, namespace_stackable(:declared_params))
      route_setting(:saved_validations, namespace_stackable(:validations))

      namespace_stackable(:representations, []) unless namespace_stackable(:representations)
      namespace_inheritable(:default_error_status, 500) unless namespace_inheritable(:default_error_status)

      @options = options

      @options[:path] = Array(options[:path])
      @options[:path] << '/' if options[:path].empty?

      @options[:method] = Array(options[:method])
      @options[:route_options] ||= {}

      if block_given?
        @source = block
        @block = self.class.generate_api_method(method_name, &block)
      end
    end

    def require_option(options, key)
      fail Grape::Exceptions::MissingOption.new(key) unless options.key?(key)
    end

    def method_name
      [options[:method],
       Namespace.joined_space(namespace_stackable(:namespace)),
       (namespace_stackable(:mount_path) || []).join('/'),
       options[:path].join('/')
      ].join(' ')
    end

    def routes
      @routes ||= endpoints ? endpoints.collect(&:routes).flatten : prepare_routes
    end

    def reset_routes!
      endpoints.map(&:reset_routes!) if endpoints
      @namespace = nil
      @routes = nil
    end

    def mount_in(route_set)
      if endpoints
        endpoints.each do |e|
          e.mount_in(route_set)
        end
      else
        @routes = nil

        routes.each do |route|
          methods = [route.route_method]
          if !namespace_inheritable(:do_not_route_head) && route.route_method == Grape::Http::Headers::GET
            methods << Grape::Http::Headers::HEAD
          end
          methods.each do |method|
            route_set.add_route(self, {
                                  path_info: route.route_compiled,
                                  request_method: method
                                },  route_info: route)
          end
        end
      end
    end

    def prepare_routes_requirements
      endpoint_requirements = options[:route_options][:requirements] || {}
      all_requirements = (namespace_stackable(:namespace).map(&:requirements) << endpoint_requirements)
      all_requirements.reduce({}) do |base_requirements, single_requirements|
        base_requirements.merge!(single_requirements)
      end
    end

    def prepare_routes_path_params(path)
      path_params = {}

      regex = Rack::Mount::RegexpWithNamedGroups.new(path)
      named_params = regex.named_captures.map { |nc| nc[0] } - %w(version format)
      named_params.each { |named_param| path_params[named_param] = '' }

      route_params = options[:route_options][:params]
      path_params.merge! route_params if route_params

      path_params
    end

    def prepare_routes
      options[:method].map do |method|
        options[:path].map do |path|
          prepared_path = prepare_path(path)
          anchor = options[:route_options].fetch(:anchor, true)
          path = compile_path(prepared_path, anchor && !options[:app], prepare_routes_requirements)
          request_method = (method.to_s.upcase unless method == :any)

          Route.new(options[:route_options].clone.merge(
                      prefix: namespace_inheritable(:root_prefix),
                      version: namespace_inheritable(:version) ? namespace_inheritable(:version).join('|') : nil,
                      namespace: namespace,
                      method: request_method,
                      path: prepared_path,
                      params: prepare_routes_path_params(path),
                      compiled: path,
                      settings: inheritable_setting.route.except(:saved_declared_params, :saved_validations)
          ))
        end
      end.flatten
    end

    def prepare_path(path)
      path_settings = inheritable_setting.to_hash[:namespace_stackable].merge(inheritable_setting.to_hash[:namespace_inheritable])
      Path.prepare(path, namespace, path_settings)
    end

    def namespace
      @namespace ||= Namespace.joined_space_path(namespace_stackable(:namespace))
    end

    def compile_path(prepared_path, anchor = true, requirements = {})
      endpoint_options = {}
      endpoint_options[:version] = /#{namespace_inheritable(:version).join('|')}/ if namespace_inheritable(:version)
      endpoint_options.merge!(requirements)
      Rack::Mount::Strexp.compile(prepared_path, endpoint_options, %w( / . ? ), anchor)
    end

    def call(env)
      dup.call!(env)
    end

    def call!(env)
      extend helpers

      env['api.endpoint'] = self
      if options[:app]
        options[:app].call(env)
      else
        builder = build_middleware
        builder.run ->(arg) { run(arg) }
        builder.call(env)
      end
    end

    def endpoints
      options[:app].endpoints if options[:app] && options[:app].respond_to?(:endpoints)
    end

    def equals?(e)
      (options == e.options) && (inheritable_setting.to_hash == e.inheritable_setting.to_hash)
    end

    protected

    def run(env)
      ActiveSupport::Notifications.instrument('endpoint_run.grape', endpoint: self, env: env) do
        @env = env
        @header = {}

        @request = Grape::Request.new(env)
        @params = @request.params
        @headers = @request.headers

        cookies.read(@request)

        self.class.before_each.call(self) if self.class.before_each

        run_filters befores, :before

        run_filters before_validations, :before_validation

        validation_errors = []


        route_setting(:saved_validations).each do |validator|
          begin
            validator.validate!(params)
          rescue Grape::Exceptions::Validation => e
            validation_errors << e
          end
        end

        if validation_errors.any?
          fail Grape::Exceptions::ValidationErrors, errors: validation_errors, headers: header
        end

        run_filters after_validations, :after_validation

        response_object = @block ? @block.call(self) : nil
        run_filters afters, :after
        cookies.write(header)

        response_object = file || [body || response_object]
        [status, header, response_object]
      end
    end

    def build_middleware
      b = Rack::Builder.new

      b.use Rack::Head
      b.use Grape::Middleware::Error,
            format: namespace_inheritable(:format),
            content_types: Grape::DSL::Configuration.stacked_hash_to_hash(namespace_stackable(:content_types)),
            default_status: namespace_inheritable(:default_error_status),
            rescue_all: namespace_inheritable(:rescue_all),
            default_error_formatter: namespace_inheritable(:default_error_formatter),
            error_formatters: Grape::DSL::Configuration.stacked_hash_to_hash(namespace_stackable(:error_formatters)),
            rescue_options: Grape::DSL::Configuration.stacked_hash_to_hash(namespace_stackable(:rescue_options)) || {},
            rescue_handlers: Grape::DSL::Configuration.stacked_hash_to_hash(namespace_stackable(:rescue_handlers)) || {},
            base_only_rescue_handlers: Grape::DSL::Configuration.stacked_hash_to_hash(namespace_stackable(:base_only_rescue_handlers)) || {},
            all_rescue_handler: namespace_inheritable(:all_rescue_handler)

      (namespace_stackable(:middleware) || []).each do |m|
        m = m.dup
        block = m.pop if m.last.is_a?(Proc)
        if block
          b.use(*m, &block)
        else
          b.use(*m)
        end
      end

      if namespace_inheritable(:version)
        b.use Grape::Middleware::Versioner.using(namespace_inheritable(:version_options)[:using]),
              versions: namespace_inheritable(:version) ? namespace_inheritable(:version).flatten : nil,
              version_options: namespace_inheritable(:version_options),
              prefix: namespace_inheritable(:root_prefix)

      end

      b.use Grape::Middleware::Formatter,
            format: namespace_inheritable(:format),
            default_format: namespace_inheritable(:default_format) || :txt,
            content_types: Grape::DSL::Configuration.stacked_hash_to_hash(namespace_stackable(:content_types)),
            formatters: Grape::DSL::Configuration.stacked_hash_to_hash(namespace_stackable(:formatters)),
            parsers: Grape::DSL::Configuration.stacked_hash_to_hash(namespace_stackable(:parsers))

      b
    end

    def helpers
      mod = Module.new
      (namespace_stackable(:helpers) || []).each do |mod_to_include|
        #nodyna <send-2827> <SD TRIVIAL (public method)>
        mod.send :include, mod_to_include
      end
      mod
    end

    def run_filters(filters, type = :other)
      ActiveSupport::Notifications.instrument('endpoint_run_filters.grape', endpoint: self, filters: filters, type: type) do
        (filters || []).each do |filter|
          #nodyna <instance_eval-2828> <IEV COMPLEX (block execution)>
          instance_eval(&filter)
        end
      end
    end

    def befores
      namespace_stackable(:befores) || []
    end

    def before_validations
      namespace_stackable(:before_validations) || []
    end

    def after_validations
      namespace_stackable(:after_validations) || []
    end

    def afters
      namespace_stackable(:afters) || []
    end
  end
end
