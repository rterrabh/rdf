require 'zlib'

module ActionView
  module Helpers
    module AssetUrlHelper
      URI_REGEXP = %r{^[-a-z]+://|^(?:cid|data):|^//}i

      def asset_path(source, options = {})
        source = source.to_s
        return "" unless source.present?
        return source if source =~ URI_REGEXP

        tail, source = source[/([\?#].+)$/], source.sub(/([\?#].+)$/, '')

        if extname = compute_asset_extname(source, options)
          source = "#{source}#{extname}"
        end

        if source[0] != ?/
          source = compute_asset_path(source, options)
        end

        relative_url_root = defined?(config.relative_url_root) && config.relative_url_root
        if relative_url_root
          source = File.join(relative_url_root, source) unless source.starts_with?("#{relative_url_root}/")
        end

        if host = compute_asset_host(source, options)
          source = File.join(host, source)
        end

        "#{source}#{tail}"
      end
      alias_method :path_to_asset, :asset_path # aliased to avoid conflicts with an asset_path named route

      def asset_url(source, options = {})
        path_to_asset(source, options.merge(:protocol => :request))
      end
      alias_method :url_to_asset, :asset_url # aliased to avoid conflicts with an asset_url named route

      ASSET_EXTENSIONS = {
        javascript: '.js',
        stylesheet: '.css'
      }

      def compute_asset_extname(source, options = {})
        return if options[:extname] == false
        extname = options[:extname] || ASSET_EXTENSIONS[options[:type]]
        extname if extname && File.extname(source) != extname
      end

      ASSET_PUBLIC_DIRECTORIES = {
        audio:      '/audios',
        font:       '/fonts',
        image:      '/images',
        javascript: '/javascripts',
        stylesheet: '/stylesheets',
        video:      '/videos'
      }

      def compute_asset_path(source, options = {})
        dir = ASSET_PUBLIC_DIRECTORIES[options[:type]] || ""
        File.join(dir, source)
      end

      def compute_asset_host(source = "", options = {})
        request = self.request if respond_to?(:request)
        host = options[:host]
        host ||= config.asset_host if defined? config.asset_host

        if host.respond_to?(:call)
          arity = host.respond_to?(:arity) ? host.arity : host.method(:call).arity
          args = [source]
          args << request if request && (arity > 1 || arity < 0)
          host = host.call(*args)
        elsif host =~ /%d/
          host = host % (Zlib.crc32(source) % 4)
        end

        host ||= request.base_url if request && options[:protocol] == :request
        return unless host

        if host =~ URI_REGEXP
          host
        else
          protocol = options[:protocol] || config.default_asset_host_protocol || (request ? :request : :relative)
          case protocol
          when :relative
            "//#{host}"
          when :request
            "#{request.protocol}#{host}"
          else
            "#{protocol}://#{host}"
          end
        end
      end

      def javascript_path(source, options = {})
        path_to_asset(source, {type: :javascript}.merge!(options))
      end
      alias_method :path_to_javascript, :javascript_path # aliased to avoid conflicts with a javascript_path named route

      def javascript_url(source, options = {})
        url_to_asset(source, {type: :javascript}.merge!(options))
      end
      alias_method :url_to_javascript, :javascript_url # aliased to avoid conflicts with a javascript_url named route

      def stylesheet_path(source, options = {})
        path_to_asset(source, {type: :stylesheet}.merge!(options))
      end
      alias_method :path_to_stylesheet, :stylesheet_path # aliased to avoid conflicts with a stylesheet_path named route

      def stylesheet_url(source, options = {})
        url_to_asset(source, {type: :stylesheet}.merge!(options))
      end
      alias_method :url_to_stylesheet, :stylesheet_url # aliased to avoid conflicts with a stylesheet_url named route

      def image_path(source, options = {})
        path_to_asset(source, {type: :image}.merge!(options))
      end
      alias_method :path_to_image, :image_path # aliased to avoid conflicts with an image_path named route

      def image_url(source, options = {})
        url_to_asset(source, {type: :image}.merge!(options))
      end
      alias_method :url_to_image, :image_url # aliased to avoid conflicts with an image_url named route

      def video_path(source, options = {})
        path_to_asset(source, {type: :video}.merge!(options))
      end
      alias_method :path_to_video, :video_path # aliased to avoid conflicts with a video_path named route

      def video_url(source, options = {})
        url_to_asset(source, {type: :video}.merge!(options))
      end
      alias_method :url_to_video, :video_url # aliased to avoid conflicts with an video_url named route

      def audio_path(source, options = {})
        path_to_asset(source, {type: :audio}.merge!(options))
      end
      alias_method :path_to_audio, :audio_path # aliased to avoid conflicts with an audio_path named route

      def audio_url(source, options = {})
        url_to_asset(source, {type: :audio}.merge!(options))
      end
      alias_method :url_to_audio, :audio_url # aliased to avoid conflicts with an audio_url named route

      def font_path(source, options = {})
        path_to_asset(source, {type: :font}.merge!(options))
      end
      alias_method :path_to_font, :font_path # aliased to avoid conflicts with an font_path named route

      def font_url(source, options = {})
        url_to_asset(source, {type: :font}.merge!(options))
      end
      alias_method :url_to_font, :font_url # aliased to avoid conflicts with an font_url named route
    end
  end
end
