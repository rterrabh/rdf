module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module Quoting
        def escape_bytea(value)
          @connection.escape_bytea(value) if value
        end

        def unescape_bytea(value)
          @connection.unescape_bytea(value) if value
        end

        def quote_string(s) #:nodoc:
          @connection.escape(s)
        end

        def quote_table_name(name)
          Utils.extract_schema_qualified_name(name.to_s).quoted
        end

        def quote_table_name_for_assignment(table, attr)
          quote_column_name(attr)
        end

        def quote_column_name(name) #:nodoc:
          PGconn.quote_ident(name.to_s)
        end

        def quoted_date(value) #:nodoc:
          result = super
          if value.acts_like?(:time) && value.respond_to?(:usec)
            result = "#{result}.#{sprintf("%06d", value.usec)}"
          end

          if value.year <= 0
            bce_year = format("%04d", -value.year + 1)
            result = result.sub(/^-?\d+/, bce_year) + " BC"
          end
          result
        end

        def quote_default_value(value, column) #:nodoc:
          if column.type == :uuid && value =~ /\(\)/
            value
          else
            quote(value, column)
          end
        end

        private

        def _quote(value)
          case value
          when Type::Binary::Data
            "'#{escape_bytea(value.to_s)}'"
          when OID::Xml::Data
            "xml '#{quote_string(value.to_s)}'"
          when OID::Bit::Data
            if value.binary?
              "B'#{value}'"
            elsif value.hex?
              "X'#{value}'"
            end
          when Float
            if value.infinite? || value.nan?
              "'#{value}'"
            else
              super
            end
          else
            super
          end
        end

        def _type_cast(value)
          case value
          when Type::Binary::Data
            { value: value.to_s, format: 1 }
          when OID::Xml::Data, OID::Bit::Data
            value.to_s
          else
            super
          end
        end
      end
    end
  end
end
