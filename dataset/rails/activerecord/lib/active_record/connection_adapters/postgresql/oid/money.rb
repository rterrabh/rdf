module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Money < Type::Decimal # :nodoc:
          include Infinity

          class_attribute :precision

          def type
            :money
          end

          def scale
            2
          end

          def cast_value(value)
            return value unless ::String === value


            value.sub!(/^\((.+)\)$/, '-\1') # (4)
            case value
            when /^-?\D+[\d,]+\.\d{2}$/  # (1)
              value.gsub!(/[^-\d.]/, '')
            when /^-?\D+[\d.]+,\d{2}$/  # (2)
              value.gsub!(/[^-\d,]/, '').sub!(/,/, '.')
            end

            super(value)
          end
        end
      end
    end
  end
end
