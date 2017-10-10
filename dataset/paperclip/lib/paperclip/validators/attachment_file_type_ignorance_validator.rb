require 'active_model/validations/presence'

module Paperclip
  module Validators
    class AttachmentFileTypeIgnoranceValidator < ActiveModel::EachValidator
      def validate_each(record, attribute, value)
      end

      def self.helper_method_name
        :do_not_validate_attachment_file_type
      end
    end

    module HelperMethods
      def do_not_validate_attachment_file_type(*attr_names)
        options = _merge_attributes(attr_names)
        validates_with AttachmentFileTypeIgnoranceValidator, options.dup
      end
    end
  end
end

