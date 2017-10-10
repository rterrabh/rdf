module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Jsonb < Json # :nodoc:
          def type
            :jsonb
          end

          def changed_in_place?(raw_old_value, new_value)
            raw_old_value = type_cast_for_database(type_cast_from_database(raw_old_value))
            super(raw_old_value, new_value)
          end
        end
      end
    end
  end
end
