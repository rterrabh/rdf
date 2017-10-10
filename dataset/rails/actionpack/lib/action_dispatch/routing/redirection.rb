require 'action_dispatch/http/request'
require 'active_support/core_ext/uri'
require 'active_support/core_ext/array/extract_options'
require 'rack/utils'
require 'action_controller/metal/exceptions'
require 'action_dispatch/routing/endpoint'

module ActionDispatch
  module Routing
    class Redirect < Endpoint # :nodoc:
      attr_reader :status, :block

      def initialize(status, block)
        @status = status
        @block  = block
      end

      def redirect?; true; end

      def call(env)
        serve Request.new env
      end

      def serve(req)
        req.check_path_parameters!
        uri = URI.parse(path(req.path_parameters, req))
        
        unless uri.host
          if relative_path?(uri.path)
            uri.path = "#{req.script_name}/#{uri.path}"
          elsif uri.path.empty?
            uri.path = req.script_name.empty? ? "/" : req.script_name
          end
        end
          
        uri.scheme ||= req.scheme
        uri.host   ||= req.host
        uri.port   ||= req.port unless req.standard_port?

        body = %(<html><body>You are being <a href="#{ERB::Util.unwrapped_html_escape(uri.to_s)}">redirected</a>.</body></html>)

        headers = {
          'Location' => uri.to_s,
          'Content-Type' => 'text/html',
          'Content-Length' => body.length.to_s
        }

        [ status, headers, [body] ]
      end

      def path(params, request)
        block.call params, request
      end

      def inspect
        "redirect(#{status})"
      end

      private
        def relative_path?(path)
          path && !path.empty? && path[0] != '/'
        end

        def escape(params)
          Hash[params.map{ |k,v| [k, Rack::Utils.escape(v)] }]
        end

        def escape_fragment(params)
          Hash[params.map{ |k,v| [k, Journey::Router::Utils.escape_fragment(v)] }]
        end

        def escape_path(params)
          Hash[params.map{ |k,v| [k, Journey::Router::Utils.escape_path(v)] }]
        end
    end

    class PathRedirect < Redirect
      URL_PARTS = /\A([^?]+)?(\?[^#]+)?(#.+)?\z/

      def path(params, request)
        if block.match(URL_PARTS)
          path     = interpolation_required?($1, params) ? $1 % escape_path(params)     : $1
          query    = interpolation_required?($2, params) ? $2 % escape(params)          : $2
          fragment = interpolation_required?($3, params) ? $3 % escape_fragment(params) : $3

          "#{path}#{query}#{fragment}"
        else
          interpolation_required?(block, params) ? block % escape(params) : block
        end
      end

      def inspect
        "redirect(#{status}, #{block})"
      end

      private
        def interpolation_required?(string, params)
          !params.empty? && string && string.match(/%\{\w*\}/)
        end
    end

    class OptionRedirect < Redirect # :nodoc:
      alias :options :block

      def path(params, request)
        url_options = {
          :protocol => request.protocol,
          :host     => request.host,
          :port     => request.optional_port,
          :path     => request.path,
          :params   => request.query_parameters
        }.merge! options

        if !params.empty? && url_options[:path].match(/%\{\w*\}/)
          url_options[:path] = (url_options[:path] % escape_path(params))
        end

        unless options[:host] || options[:domain]
          if relative_path?(url_options[:path])
            url_options[:path] = "/#{url_options[:path]}"
            url_options[:script_name] = request.script_name
          elsif url_options[:path].empty?
            url_options[:path] = request.script_name.empty? ? "/" : ""
            url_options[:script_name] = request.script_name
          end
        end
        
        ActionDispatch::Http::URL.url_for url_options
      end

      def inspect
        "redirect(#{status}, #{options.map{ |k,v| "#{k}: #{v}" }.join(', ')})"
      end
    end

    module Redirection

      def redirect(*args, &block)
        options = args.extract_options!
        status  = options.delete(:status) || 301
        path    = args.shift

        return OptionRedirect.new(status, options) if options.any?
        return PathRedirect.new(status, path) if String === path

        block = path if path.respond_to? :call
        raise ArgumentError, "redirection argument not supported" unless block
        Redirect.new status, block
      end
    end
  end
end
