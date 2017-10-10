module ActiveRecord
  module Validations
    class AssociatedValidator < ActiveModel::EachValidator #:nodoc:
      def validate_each(record, attribute, value)
        if Array.wrap(value).reject {|r| r.marked_for_destruction? || r.valid?}.any?
          record.errors.add(attribute, :invalid, options.merge(:value => value))
        end
      end
    end

    module ClassMethods
      def validates_associated(*attr_names)
        validates_with AssociatedValidator, _merge_attributes(attr_names)
      end
    end
  end
end
