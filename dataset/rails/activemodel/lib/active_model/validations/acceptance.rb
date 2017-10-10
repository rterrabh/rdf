module ActiveModel

  module Validations
    class AcceptanceValidator < EachValidator # :nodoc:
      def initialize(options)
        super({ allow_nil: true, accept: "1" }.merge!(options))
        setup!(options[:class])
      end

      def validate_each(record, attribute, value)
        unless value == options[:accept]
          record.errors.add(attribute, :accepted, options.except(:accept, :allow_nil))
        end
      end

      private
      def setup!(klass)
        attr_readers = attributes.reject { |name| klass.attribute_method?(name) }
        attr_writers = attributes.reject { |name| klass.attribute_method?("#{name}=") }
        #nodyna <send-943> <SD COMPLEX (private methods)>
        klass.send(:attr_reader, *attr_readers)
        #nodyna <send-944> <SD COMPLEX (private methods)>
        klass.send(:attr_writer, *attr_writers)
      end
    end

    module HelperMethods
      def validates_acceptance_of(*attr_names)
        validates_with AcceptanceValidator, _merge_attributes(attr_names)
      end
    end
  end
end
