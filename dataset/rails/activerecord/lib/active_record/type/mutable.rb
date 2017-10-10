module ActiveRecord
  module Type
    module Mutable # :nodoc:
      def type_cast_from_user(value)
        type_cast_from_database(type_cast_for_database(value))
      end

      def changed_in_place?(raw_old_value, new_value)
        raw_old_value != type_cast_for_database(new_value)
      end
    end
  end
end
