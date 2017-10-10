module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Cidr < Type::Value # :nodoc:
          def type
            :cidr
          end

          def type_cast_for_schema(value)
            #nodyna <instance_variable_get-918> <not yet classified>
            subnet_mask = value.instance_variable_get(:@mask_addr)

            if subnet_mask == (2**32 - 1)
              "\"#{value}\""
            else
              "\"#{value}/#{subnet_mask.to_s(2).count('1')}\""
            end
          end

          def type_cast_for_database(value)
            if IPAddr === value
              #nodyna <instance_variable_get-919> <not yet classified>
              "#{value}/#{value.instance_variable_get(:@mask_addr).to_s(2).count('1')}"
            else
              value
            end
          end

          def cast_value(value)
            if value.nil?
              nil
            elsif String === value
              begin
                IPAddr.new(value)
              rescue ArgumentError
                nil
              end
            else
              value
            end
          end
        end
      end
    end
  end
end
