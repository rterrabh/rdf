require 'active_model/validations/presence'

module Paperclip
  module Validators
    class AttachmentPresenceValidator < ActiveModel::EachValidator
      def validate_each(record, attribute, value)
        #nodyna <send-705> <SD COMPLEX (change-prone variables)>
        if record.send("#{attribute}_file_name").blank?
          record.errors.add(attribute, :blank, options)
        end
      end

      def self.helper_method_name
        :validates_attachment_presence
      end
    end

    module HelperMethods
      def validates_attachment_presence(*attr_names)
        options = _merge_attributes(attr_names)
        validates_with AttachmentPresenceValidator, options.dup
        validate_before_processing AttachmentPresenceValidator, options.dup
      end
    end
  end
end
