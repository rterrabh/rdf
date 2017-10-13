
module CarrierWave

  module MimeTypes
    extend ActiveSupport::Concern

    included do
      CarrierWave::Utilities::Deprecation.new "0.11.0", "CarrierWave::MimeTypes is deprecated and will be removed in the future, get the content_type from the SanitizedFile object directly."
      begin
        require "mime/types"
      rescue LoadError => e
        e.message << " (You may need to install the mime-types gem)"
        raise e
      end
    end

    module ClassMethods
      def set_content_type(override=false)
        process :set_content_type => override
      end
    end

    GENERIC_CONTENT_TYPES = %w[application/octet-stream binary/octet-stream]

    def generic_content_type?
      GENERIC_CONTENT_TYPES.include? file.content_type
    end

    def set_content_type(override=false)
      if override || file.content_type.blank? || generic_content_type?
        new_content_type = ::MIME::Types.type_for(file.original_filename).first.to_s
        if file.respond_to?(:content_type=)
          file.content_type = new_content_type
        else
          #nodyna <instance_variable_set-2663> <IVS COMPLEX (private access)>
          file.instance_variable_set(:@content_type, new_content_type)
        end
      end
    rescue ::MIME::InvalidContentType => e
      raise CarrierWave::ProcessingError, I18n.translate(:"errors.messages.mime_types_processing_error", :e => e)
    end

  end # MimeTypes
end # CarrierWave
