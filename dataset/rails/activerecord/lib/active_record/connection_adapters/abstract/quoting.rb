require 'active_support/core_ext/big_decimal/conversions'

module ActiveRecord
  module ConnectionAdapters # :nodoc:
    module Quoting
      def quote(value, column = nil)
        return value.quoted_id if value.respond_to?(:quoted_id)

        if column
          value = column.cast_type.type_cast_for_database(value)
        end

        _quote(value)
      end

      def type_cast(value, column)
        if value.respond_to?(:quoted_id) && value.respond_to?(:id)
          return value.id
        end

        if column
          value = column.cast_type.type_cast_for_database(value)
        end

        _type_cast(value)
      rescue TypeError
        to_type = column ? " to #{column.type}" : ""
        raise TypeError, "can't cast #{value.class}#{to_type}"
      end

      def quote_string(s)
        s.gsub(/\\/, '\&\&').gsub(/'/, "''") # ' (for ruby-mode)
      end

      def quote_column_name(column_name)
        column_name
      end

      def quote_table_name(table_name)
        quote_column_name(table_name)
      end

      def quote_table_name_for_assignment(table, attr)
        quote_table_name("#{table}.#{attr}")
      end

      def quoted_true
        "'t'"
      end

      def unquoted_true
        't'
      end

      def quoted_false
        "'f'"
      end

      def unquoted_false
        'f'
      end

      def quoted_date(value)
        if value.acts_like?(:time)
          zone_conversion_method = ActiveRecord::Base.default_timezone == :utc ? :getutc : :getlocal

          if value.respond_to?(zone_conversion_method)
            #nodyna <send-915> <SD MODERATE (change-prone variables)>
            value = value.send(zone_conversion_method)
          end
        end

        value.to_s(:db)
      end

      private

      def types_which_need_no_typecasting
        [nil, Numeric, String]
      end

      def _quote(value)
        case value
        when String, ActiveSupport::Multibyte::Chars, Type::Binary::Data
          "'#{quote_string(value.to_s)}'"
        when true       then quoted_true
        when false      then quoted_false
        when nil        then "NULL"
        when BigDecimal then value.to_s('F')
        when Numeric, ActiveSupport::Duration then value.to_s
        when Date, Time then "'#{quoted_date(value)}'"
        when Symbol     then "'#{quote_string(value.to_s)}'"
        when Class      then "'#{value}'"
        else
          "'#{quote_string(YAML.dump(value))}'"
        end
      end

      def _type_cast(value)
        case value
        when Symbol, ActiveSupport::Multibyte::Chars, Type::Binary::Data
          value.to_s
        when true       then unquoted_true
        when false      then unquoted_false
        when BigDecimal then value.to_s('F')
        when Date, Time then quoted_date(value)
        when *types_which_need_no_typecasting
          value
        else raise TypeError
        end
      end
    end
  end
end
