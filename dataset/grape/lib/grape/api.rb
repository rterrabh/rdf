module Grape
  class API
    include Grape::DSL::API

    class << self
      attr_reader :instance

      LOCK = Mutex.new

      def reset!
        @route_set = Rack::Mount::RouteSet.new
        @endpoints = []
        @routes = nil
        reset_validations!
      end

      def compile
        @instance ||= new
      end

      def change!
        @instance = nil
      end

      def call(env)
        LOCK.synchronize { compile } unless instance
        call!(env)
      end

      def call!(env)
        instance.call(env)
      end

      def scope(_name = nil, &block)
        within_namespace do
          nest(block)
        end
      end

      def cascade(value = nil)
        if value.nil?
          inheritable_setting.namespace_inheritable.keys.include?(:cascade) ? !!namespace_inheritable(:cascade) : true
        else
          namespace_inheritable(:cascade, value)
        end
      end

      protected

      def prepare_routes
        endpoints.map(&:routes).flatten
      end

      def nest(*blocks, &block)
        blocks.reject!(&:nil?)
        if blocks.any?
          #nodyna <instance_eval-2822> <not yet classified>
          instance_eval(&block) if block_given?
          #nodyna <instance_eval-2823> <not yet classified>
          blocks.each { |b| instance_eval(&b) }
          reset_validations!
        else
          #nodyna <instance_eval-2824> <not yet classified>
          instance_eval(&block)
        end
      end

      def inherited(subclass)
        subclass.reset!
        subclass.logger = logger.clone
      end

      def inherit_settings(other_settings)
        top_level_setting.inherit_from other_settings.point_in_time_copy

        endpoints.each(&:reset_routes!)

        @routes = nil
      end
    end

    def initialize
      @route_set = Rack::Mount::RouteSet.new
      add_head_not_allowed_methods_and_options_methods
      self.class.endpoints.each do |endpoint|
        endpoint.mount_in(@route_set)
      end

      @route_set.freeze
    end

    def call(env)
      result = @route_set.call(env)
      result[1].delete(Grape::Http::Headers::X_CASCADE) unless cascade?
      result
    end

    def cascade?
      return !!self.class.namespace_inheritable(:cascade) if self.class.inheritable_setting.namespace_inheritable.keys.include?(:cascade)
      return !!self.class.namespace_inheritable(:version_options)[:cascade] if self.class.namespace_inheritable(:version_options) && self.class.namespace_inheritable(:version_options).key?(:cascade)
      true
    end

    reset!

    private

    def add_head_not_allowed_methods_and_options_methods
      methods_per_path = {}

      self.class.endpoints.each do |endpoint|
        routes = endpoint.routes
        routes.each do |route|
          methods_per_path[route.route_path] ||= []
          methods_per_path[route.route_path] << route.route_method
        end
      end

      without_root_prefix do
        without_versioning do
          methods_per_path.each do |path, methods|
            allowed_methods = methods.dup
            unless self.class.namespace_inheritable(:do_not_route_head)
              allowed_methods |= [Grape::Http::Headers::HEAD] if allowed_methods.include?(Grape::Http::Headers::GET)
            end

            allow_header = ([Grape::Http::Headers::OPTIONS] | allowed_methods).join(', ')
            unless self.class.namespace_inheritable(:do_not_route_options)
              unless allowed_methods.include?(Grape::Http::Headers::OPTIONS)
                self.class.options(path, {}) do
                  header 'Allow', allow_header
                  status 204
                  ''
                end
              end
            end

            not_allowed_methods = %w(GET PUT POST DELETE PATCH HEAD) - allowed_methods
            not_allowed_methods << Grape::Http::Headers::OPTIONS if self.class.namespace_inheritable(:do_not_route_options)
            self.class.route(not_allowed_methods, path) do
              header 'Allow', allow_header
              status 405
              ''
            end
          end
        end
      end
    end

    def without_versioning(&_block)
      old_version = self.class.namespace_inheritable(:version)
      old_version_options = self.class.namespace_inheritable(:version_options)

      self.class.namespace_inheritable_to_nil(:version)
      self.class.namespace_inheritable_to_nil(:version_options)

      yield

      self.class.namespace_inheritable(:version, old_version)
      self.class.namespace_inheritable(:version_options, old_version_options)
    end

    def without_root_prefix(&_block)
      old_prefix = self.class.namespace_inheritable(:root_prefix)

      self.class.namespace_inheritable_to_nil(:root_prefix)

      yield

      self.class.namespace_inheritable(:root_prefix, old_prefix)
    end
  end
end
