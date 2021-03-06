require 'active_model/validations/presence'

module Paperclip
  module Validators
    class MediaTypeSpoofDetectionValidator < ActiveModel::EachValidator
      def validate_each(record, attribute, value)
        adapter = Paperclip.io_adapters.for(value)
        if Paperclip::MediaTypeSpoofDetector.using(adapter, value.original_filename, value.content_type).spoofed?
          record.errors.add(attribute, :spoofed_media_type)
        end
      end
    end

    module HelperMethods
      def validates_media_type_spoof_detection(*attr_names)
        options = _merge_attributes(attr_names)
        validates_with MediaTypeSpoofDetectionValidator, options.dup
        validate_before_processing MediaTypeSpoofDetectionValidator, options.dup
      end
    end
  end
end
