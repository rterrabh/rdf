require 'rack/utils'
require 'active_support/core_ext/uri'

module ActionDispatch
  class FileHandler
    def initialize(root, cache_control)
      @root          = root.chomp('/')
      @compiled_root = /^#{Regexp.escape(root)}/
      headers        = cache_control && { 'Cache-Control' => cache_control }
      @file_server = ::Rack::File.new(@root, headers)
    end

    def match?(path)
      path = URI.parser.unescape(path)
      return false unless path.valid_encoding?

      paths = [path, "#{path}#{ext}", "#{path}/index#{ext}"].map { |v|
        Rack::Utils.clean_path_info v
      }

      if match = paths.detect { |p|
        path = File.join(@root, p.force_encoding('UTF-8'))
        begin
          File.file?(path) && File.readable?(path)
        rescue SystemCallError
          false
        end

      }
        return ::Rack::Utils.escape(match)
      end
    end

    def call(env)
      path      = env['PATH_INFO']
      gzip_path = gzip_file_path(path)

      if gzip_path && gzip_encoding_accepted?(env)
        env['PATH_INFO']            = gzip_path
        status, headers, body       = @file_server.call(env)
        if status == 304
          return [status, headers, body]
        end
        headers['Content-Encoding'] = 'gzip'
        headers['Content-Type']     = content_type(path)
      else
        status, headers, body = @file_server.call(env)
      end

      headers['Vary'] = 'Accept-Encoding' if gzip_path

      return [status, headers, body]
    ensure
      env['PATH_INFO'] = path
    end

    private
      def ext
        ::ActionController::Base.default_static_extension
      end

      def content_type(path)
        ::Rack::Mime.mime_type(::File.extname(path), 'text/plain')
      end

      def gzip_encoding_accepted?(env)
        env['HTTP_ACCEPT_ENCODING'] =~ /\bgzip\b/i
      end

      def gzip_file_path(path)
        can_gzip_mime = content_type(path) =~ /\A(?:text\/|application\/javascript)/
        gzip_path     = "#{path}.gz"
        if can_gzip_mime && File.exist?(File.join(@root, ::Rack::Utils.unescape(gzip_path)))
          gzip_path
        else
          false
        end
      end
  end

  class Static
    def initialize(app, path, cache_control=nil)
      @app = app
      @file_handler = FileHandler.new(path, cache_control)
    end

    def call(env)
      case env['REQUEST_METHOD']
      when 'GET', 'HEAD'
        path = env['PATH_INFO'].chomp('/')
        if match = @file_handler.match?(path)
          env["PATH_INFO"] = match
          return @file_handler.call(env)
        end
      end

      @app.call(env)
    end
  end
end
