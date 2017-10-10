require 'rack/chunked'

module ActionController #:nodoc:
  module Streaming
    extend ActiveSupport::Concern

    protected

      def _process_options(options) #:nodoc:
        super
        if options[:stream]
          if env["HTTP_VERSION"] == "HTTP/1.0"
            options.delete(:stream)
          else
            headers["Cache-Control"] ||= "no-cache"
            headers["Transfer-Encoding"] = "chunked"
            headers.delete("Content-Length")
          end
        end
      end

      def _render_template(options) #:nodoc:
        if options.delete(:stream)
          Rack::Chunked::Body.new view_renderer.render_body(view_context, options)
        else
          super
        end
      end
  end
end
