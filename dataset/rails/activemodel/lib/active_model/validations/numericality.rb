module ActiveModel

  module Validations
    class NumericalityValidator < EachValidator # :nodoc:
      CHECKS = { greater_than: :>, greater_than_or_equal_to: :>=,
                 equal_to: :==, less_than: :<, less_than_or_equal_to: :<=,
                 odd: :odd?, even: :even?, other_than: :!= }.freeze

      RESERVED_OPTIONS = CHECKS.keys + [:only_integer]

      def check_validity!
        keys = CHECKS.keys - [:odd, :even]
        options.slice(*keys).each do |option, value|
          unless value.is_a?(Numeric) || value.is_a?(Proc) || value.is_a?(Symbol)
            raise ArgumentError, ":#{option} must be a number, a symbol or a proc"
          end
        end
      end

      def validate_each(record, attr_name, value)
        before_type_cast = :"#{attr_name}_before_type_cast"

        #nodyna <send-950> <SD COMPLEX (change-prone variables)>
        raw_value = record.send(before_type_cast) if record.respond_to?(before_type_cast)
        raw_value ||= value

        if record_attribute_changed_in_place?(record, attr_name)
          raw_value = value
        end

        return if options[:allow_nil] && raw_value.nil?

        unless value = parse_raw_value_as_a_number(raw_value)
          record.errors.add(attr_name, :not_a_number, filtered_options(raw_value))
          return
        end

        if allow_only_integer?(record)
          unless value = parse_raw_value_as_an_integer(raw_value)
            record.errors.add(attr_name, :not_an_integer, filtered_options(raw_value))
            return
          end
        end

        options.slice(*CHECKS.keys).each do |option, option_value|
          case option
          when :odd, :even
            #nodyna <send-951> <SD MODERATE (change-prone variables)>
            unless value.to_i.send(CHECKS[option])
              record.errors.add(attr_name, option, filtered_options(value))
            end
          else
            case option_value
            when Proc
              option_value = option_value.call(record)
            when Symbol
              #nodyna <send-952> <SD MODERATE (change-prone variables)>
              option_value = record.send(option_value)
            end

            #nodyna <send-953> <SD MODERATE (change-prone variables)>
            unless value.send(CHECKS[option], option_value)
              record.errors.add(attr_name, option, filtered_options(value).merge!(count: option_value))
            end
          end
        end
      end

    protected

      def parse_raw_value_as_a_number(raw_value)
        Kernel.Float(raw_value) if raw_value !~ /\A0[xX]/
      rescue ArgumentError, TypeError
        nil
      end

      def parse_raw_value_as_an_integer(raw_value)
        raw_value.to_i if raw_value.to_s =~ /\A[+-]?\d+\z/
      end

      def filtered_options(value)
        filtered = options.except(*RESERVED_OPTIONS)
        filtered[:value] = value
        filtered
      end

      def allow_only_integer?(record)
        case options[:only_integer]
        when Symbol
          #nodyna <send-954> <SD COMPLEX (change-prone variables)>
          record.send(options[:only_integer])
        when Proc
          options[:only_integer].call(record)
        else
          options[:only_integer]
        end
      end

      private

      def record_attribute_changed_in_place?(record, attr_name)
        record.respond_to?(:attribute_changed_in_place?) &&
          record.attribute_changed_in_place?(attr_name.to_s)
      end
    end

    module HelperMethods
      def validates_numericality_of(*attr_names)
        validates_with NumericalityValidator, _merge_attributes(attr_names)
      end
    end
  end
end
