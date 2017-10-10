module ActiveModel

  module Validations
    class ConfirmationValidator < EachValidator # :nodoc:
      def initialize(options)
        super
        setup!(options[:class])
      end

      def validate_each(record, attribute, value)
        #nodyna <send-947> <SD COMPLEX (change-prone variables)>
        if (confirmed = record.send("#{attribute}_confirmation")) && (value != confirmed)
          human_attribute_name = record.class.human_attribute_name(attribute)
          record.errors.add(:"#{attribute}_confirmation", :confirmation, options.merge(attribute: human_attribute_name))
        end
      end

      private
      def setup!(klass)
        #nodyna <send-948> <SD COMPLEX (private methods)>
        klass.send(:attr_reader, *attributes.map do |attribute|
          :"#{attribute}_confirmation" unless klass.method_defined?(:"#{attribute}_confirmation")
        end.compact)

        #nodyna <send-949> <SD COMPLEX (private methods)>
        klass.send(:attr_writer, *attributes.map do |attribute|
          :"#{attribute}_confirmation" unless klass.method_defined?(:"#{attribute}_confirmation=")
        end.compact)
      end
    end

    module HelperMethods
      def validates_confirmation_of(*attr_names)
        validates_with ConfirmationValidator, _merge_attributes(attr_names)
      end
    end
  end
end
