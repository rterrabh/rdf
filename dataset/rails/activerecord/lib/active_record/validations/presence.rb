module ActiveRecord
  module Validations
    class PresenceValidator < ActiveModel::Validations::PresenceValidator # :nodoc:
      def validate(record)
        super
        attributes.each do |attribute|
          next unless record.class._reflect_on_association(attribute)
          #nodyna <send-811> <SD COMPLEX (array)>
          associated_records = Array.wrap(record.send(attribute))

          if associated_records.present? && associated_records.all? { |r| r.marked_for_destruction? }
            record.errors.add(attribute, :blank, options)
          end
        end
      end
    end

    module ClassMethods
      def validates_presence_of(*attr_names)
        validates_with PresenceValidator, _merge_attributes(attr_names)
      end
    end
  end
end
