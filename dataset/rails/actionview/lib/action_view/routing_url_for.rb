require 'action_dispatch/routing/polymorphic_routes'

module ActionView
  module RoutingUrlFor

    def url_for(options = nil)
      case options
      when String
        options
      when nil
        super(only_path: _generate_paths_by_default)
      when Hash
        options = options.symbolize_keys
        unless options.key?(:only_path)
          if options[:host].nil?
            options[:only_path] = _generate_paths_by_default
          else
            options[:only_path] = false
          end
        end

        super(options)
      when :back
        _back_url
      when Array
        if _generate_paths_by_default
          polymorphic_path(options, options.extract_options!)
        else
          polymorphic_url(options, options.extract_options!)
        end
      else
        method = _generate_paths_by_default ? :path : :url
        #nodyna <send-1195> <SD TRIVIAL (public methods)>
        builder = ActionDispatch::Routing::PolymorphicRoutes::HelperMethodBuilder.send(method)

        case options
        when Symbol
          builder.handle_string_call(self, options)
        when Class
          builder.handle_class_call(self, options)
        else
          builder.handle_model_call(self, options)
        end
      end
    end

    def url_options #:nodoc:
      return super unless controller.respond_to?(:url_options)
      controller.url_options
    end

    def _routes_context #:nodoc:
      controller
    end
    protected :_routes_context

    def optimize_routes_generation? #:nodoc:
      controller.respond_to?(:optimize_routes_generation?, true) ?
        controller.optimize_routes_generation? : super
    end
    protected :optimize_routes_generation?
  end
end
