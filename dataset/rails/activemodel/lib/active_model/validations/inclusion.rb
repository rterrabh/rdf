require "active_model/validations/clusivity"

module ActiveModel

  module Validations
    class InclusionValidator < EachValidator # :nodoc:
      include Clusivity

      def validate_each(record, attribute, value)
        unless include?(record, value)
          record.errors.add(attribute, :inclusion, options.except(:in, :within).merge!(value: value))
        end
      end
    end

    module HelperMethods
      def validates_inclusion_of(*attr_names)
        validates_with InclusionValidator, _merge_attributes(attr_names)
      end
    end
  end
end
