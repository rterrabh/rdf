
module CarrierWave
  module Storage

    class Abstract

      attr_reader :uploader

      def initialize(uploader)
        @uploader = uploader
      end

      def identifier
        uploader.filename
      end

      def store!(file)
      end

      def retrieve!(identifier)
      end

    end # Abstract
  end # Storage
end # CarrierWave
