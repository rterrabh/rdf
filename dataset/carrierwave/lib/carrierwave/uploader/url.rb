
module CarrierWave
  module Uploader
    module Url
      extend ActiveSupport::Concern
      include CarrierWave::Uploader::Configuration
      include CarrierWave::Utilities::Uri

      def url(options = {})
        if file.respond_to?(:url) and not file.url.blank?
          file.method(:url).arity == 0 ? file.url : file.url(options)
        elsif file.respond_to?(:path)
          path = encode_path(file.path.gsub(File.expand_path(root), ''))

          if host = asset_host
            if host.respond_to? :call
              "#{host.call(file)}#{path}"
            else
              "#{host}#{path}"
            end
          else
            (base_path || "") + path
          end
        end
      end

      def to_s
        url || ''
      end

    end # Url
  end # Uploader
end # CarrierWave
