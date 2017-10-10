
module CarrierWave
  module Uploader
    module Proxy

      def blank?
        file.blank?
      end

      def current_path
        file.path if file.respond_to?(:path)
      end

      alias_method :path, :current_path

      def identifier
        storage.identifier if storage.respond_to?(:identifier)
      end

      def read
        file.read if file.respond_to?(:read)
      end

      def size
        file.respond_to?(:size) ? file.size : 0
      end

      def length
        size
      end

      def content_type
        file.respond_to?(:content_type) ? file.content_type : nil
      end

    end # Proxy
  end # Uploader
end # CarrierWave
