module ActiveModel
  module Validations
    module HelperMethods
      private
        def _merge_attributes(attr_names)
          options = attr_names.extract_options!.symbolize_keys
          attr_names.flatten!
          options[:attributes] = attr_names
          options
        end
    end

    class WithValidator < EachValidator # :nodoc:
      def validate_each(record, attr, val)
        method_name = options[:with]

        if record.method(method_name).arity == 0
          #nodyna <send-956> <SD COMPLEX (change-prone variables)>
          record.send method_name
        else
          #nodyna <send-957> <SD COMPLEX (change-prone variables)>
          record.send method_name, attr
        end
      end
    end

    module ClassMethods
      def validates_with(*args, &block)
        options = args.extract_options!
        options[:class] = self

        args.each do |klass|
          validator = klass.new(options, &block)

          if validator.respond_to?(:attributes) && !validator.attributes.empty?
            validator.attributes.each do |attribute|
              _validators[attribute.to_sym] << validator
            end
          else
            _validators[nil] << validator
          end

          validate(validator, options)
        end
      end
    end

    def validates_with(*args, &block)
      options = args.extract_options!
      options[:class] = self.class

      args.each do |klass|
        validator = klass.new(options, &block)
        validator.validate(self)
      end
    end
  end
end
