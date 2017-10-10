module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Vector < Type::Value # :nodoc:
          attr_reader :delim, :subtype

          def initialize(delim, subtype)
            @delim   = delim
            @subtype = subtype
          end

          def type_cast(value)
            value
          end
        end
      end
    end
  end
end
