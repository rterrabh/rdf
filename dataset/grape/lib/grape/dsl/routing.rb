require 'active_support/concern'

module Grape
  module DSL
    module Routing
      extend ActiveSupport::Concern
      include Grape::DSL::Configuration

      module ClassMethods
        attr_reader :endpoints, :routes, :route_set

        def version(*args, &block)
          if args.any?
            options = args.pop if args.last.is_a? Hash
            options ||= {}
            options = { using: :path }.merge(options)

            fail Grape::Exceptions::MissingVendorOption.new if options[:using] == :header && !options.key?(:vendor)

            @versions = versions | args

            if block_given?
              within_namespace do
                namespace_inheritable(:version, args)
                namespace_inheritable(:version_options, options)

                #nodyna <instance_eval-2815> <not yet classified>
                instance_eval(&block)
              end
            else
              namespace_inheritable(:version, args)
              namespace_inheritable(:version_options, options)
            end

          end

          @versions.last unless @versions.nil?
        end

        def prefix(prefix = nil)
          namespace_inheritable(:root_prefix, prefix)
        end

        def do_not_route_head!
          namespace_inheritable(:do_not_route_head, true)
        end

        def do_not_route_options!
          namespace_inheritable(:do_not_route_options, true)
        end

        def mount(mounts)
          mounts = { mounts => '/' } unless mounts.respond_to?(:each_pair)
          mounts.each_pair do |app, path|
            in_setting = inheritable_setting

            if app.respond_to?(:inheritable_setting, true)
              mount_path = Rack::Mount::Utils.normalize_path(path)
              app.top_level_setting.namespace_stackable[:mount_path] =  mount_path

              app.inherit_settings(inheritable_setting)

              in_setting = app.top_level_setting


              app.change!
              change!
            end

            endpoints << Grape::Endpoint.new(
              in_setting,
              method: :any,
              path: path,
              app: app,
              for: self
            )
          end
        end

        def route(methods, paths = ['/'], route_options = {}, &block)
          endpoint_options = {
            method: methods,
            path: paths,
            for: self,
            route_options: ({
              params: Grape::DSL::Configuration.stacked_hash_to_hash(namespace_stackable(:params)) || {}
            }).deep_merge(route_setting(:description) || {}).deep_merge(route_options || {})
          }

          new_endpoint = Grape::Endpoint.new(inheritable_setting, endpoint_options, &block)
          endpoints << new_endpoint unless endpoints.any? { |e| e.equals?(new_endpoint) }

          route_end
          reset_validations!
        end

        %w(get post put head delete options patch).each do |meth|
          #nodyna <define_method-2816> <not yet classified>
          define_method meth do |*args, &block|
            options = args.extract_options!
            paths = args.first || ['/']
            route(meth.upcase, paths, options, &block)
          end
        end

        def namespace(space = nil, options = {}, &block)
          if space || block_given?
            within_namespace do
              previous_namespace_description = @namespace_description
              @namespace_description = (@namespace_description || {}).deep_merge(namespace_setting(:description) || {})
              nest(block) do
                if space
                  namespace_stackable(:namespace, Namespace.new(space, options))
                end
              end
              @namespace_description = previous_namespace_description
            end
          else
            Namespace.joined_space_path(namespace_stackable(:namespace))
          end
        end

        alias_method :group, :namespace
        alias_method :resource, :namespace
        alias_method :resources, :namespace
        alias_method :segment, :namespace

        def routes
          @routes ||= prepare_routes
        end

        def reset_routes!
          @routes = nil
        end

        def route_param(param, options = {}, &block)
          options = options.dup
          options[:requirements] = { param.to_sym => options[:requirements] } if options[:requirements].is_a?(Regexp)
          namespace(":#{param}", options, &block)
        end

        def versions
          @versions ||= []
        end
      end
    end
  end
end
