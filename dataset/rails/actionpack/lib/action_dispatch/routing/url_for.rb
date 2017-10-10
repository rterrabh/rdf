module ActionDispatch
  module Routing
    module UrlFor
      extend ActiveSupport::Concern
      include PolymorphicRoutes

      included do
        unless method_defined?(:default_url_options)
          if respond_to?(:class_attribute)
            class_attribute :default_url_options
          else
            mattr_writer :default_url_options
          end

          self.default_url_options = {}
        end

        include(*_url_for_modules) if respond_to?(:_url_for_modules)
      end

      def initialize(*)
        @_routes = nil
        super
      end

      def url_options
        default_url_options
      end

      def url_for(options = nil)
        case options
        when nil
          _routes.url_for(url_options.symbolize_keys)
        when Hash
          route_name = options.delete :use_route
          _routes.url_for(options.symbolize_keys.reverse_merge!(url_options),
                         route_name)
        when String
          options
        when Symbol
          HelperMethodBuilder.url.handle_string_call self, options
        when Array
          polymorphic_url(options, options.extract_options!)
        when Class
          HelperMethodBuilder.url.handle_class_call self, options
        else
          HelperMethodBuilder.url.handle_model_call self, options
        end
      end

      protected

      def optimize_routes_generation?
        _routes.optimize_routes_generation? && default_url_options.empty?
      end

      def _with_routes(routes)
        old_routes, @_routes = @_routes, routes
        yield
      ensure
        @_routes = old_routes
      end

      def _routes_context
        self
      end

      private

        def _generate_paths_by_default
          true
        end
    end
  end
end
