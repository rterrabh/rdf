
module ActiveModel

  module Validations
    class PresenceValidator < EachValidator # :nodoc:
      def validate_each(record, attr_name, value)
        record.errors.add(attr_name, :blank, options) if value.blank?
      end
    end

    module HelperMethods
      def validates_presence_of(*attr_names)
        validates_with PresenceValidator, _merge_attributes(attr_names)
      end
    end
  end
end
