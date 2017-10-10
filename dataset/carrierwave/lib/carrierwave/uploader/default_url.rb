
module CarrierWave
  module Uploader
    module DefaultUrl

      def url(*args)
        super || default_url
      end

      def default_url; end

    end # DefaultPath
  end # Uploader
end # CarrierWave
