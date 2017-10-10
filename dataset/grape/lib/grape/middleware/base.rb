module Grape
  module Middleware
    class Base
      attr_reader :app, :env, :options

      def initialize(app, options = {})
        @app = app
        @options = default_options.merge(options)
      end

      def default_options
        {}
      end

      def call(env)
        dup.call!(env)
      end

      def call!(env)
        @env = env
        before
        @app_response = @app.call(@env)
        after || @app_response
      end

      def before
      end

      def after
      end

      def response
        return @app_response if @app_response.is_a?(Rack::Response)
        Rack::Response.new(@app_response[2], @app_response[0], @app_response[1])
      end

      def content_type_for(format)
        HashWithIndifferentAccess.new(content_types)[format]
      end

      def content_types
        ContentTypes.content_types_for(options[:content_types])
      end

      def content_type
        content_type_for(env['api.format'] || options[:format]) || 'text/html'
      end

      def mime_types
        content_types.each_with_object({}) do |(k, v), types_without_params|
          types_without_params[k] = v.split(';').first
        end.invert
      end
    end
  end
end
