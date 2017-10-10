require 'active_support/core_ext/hash/slice'

module ActiveModel
  module Validations
    module ClassMethods
      def validates(*attributes)
        defaults = attributes.extract_options!.dup
        validations = defaults.slice!(*_validates_default_keys)

        raise ArgumentError, "You need to supply at least one attribute" if attributes.empty?
        raise ArgumentError, "You need to supply at least one validation" if validations.empty?

        defaults[:attributes] = attributes

        validations.each do |key, options|
          next unless options
          key = "#{key.to_s.camelize}Validator"

          begin
            #nodyna <const_get-942> <CG COMPLEX (change-prone variable)>
            validator = key.include?('::') ? key.constantize : const_get(key)
          rescue NameError
            raise ArgumentError, "Unknown validator: '#{key}'"
          end

          validates_with(validator, defaults.merge(_parse_validates_options(options)))
        end
      end

      def validates!(*attributes)
        options = attributes.extract_options!
        options[:strict] = true
        validates(*(attributes << options))
      end

    protected

      def _validates_default_keys # :nodoc:
        [:if, :unless, :on, :allow_blank, :allow_nil , :strict]
      end

      def _parse_validates_options(options) # :nodoc:
        case options
        when TrueClass
          {}
        when Hash
          options
        when Range, Array
          { in: options }
        else
          { with: options }
        end
      end
    end
  end
end
