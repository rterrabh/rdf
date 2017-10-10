require "active_model/validations/clusivity"

module ActiveModel

  module Validations
    class ExclusionValidator < EachValidator # :nodoc:
      include Clusivity

      def validate_each(record, attribute, value)
        if include?(record, value)
          record.errors.add(attribute, :exclusion, options.except(:in, :within).merge!(value: value))
        end
      end
    end

    module HelperMethods
      def validates_exclusion_of(*attr_names)
        validates_with ExclusionValidator, _merge_attributes(attr_names)
      end
    end
  end
end
