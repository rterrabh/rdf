module ActiveRecord
  module Type
    class Value # :nodoc:
      attr_reader :precision, :scale, :limit

      def initialize(options = {})
        options.assert_valid_keys(:precision, :scale, :limit)
        @precision = options[:precision]
        @scale = options[:scale]
        @limit = options[:limit]
      end

      def type; end

      def type_cast_from_database(value)
        type_cast(value)
      end

      def type_cast_from_user(value)
        type_cast(value)
      end

      def type_cast_for_database(value)
        value
      end

      def type_cast_for_schema(value) # :nodoc:
        value.inspect
      end

      def text? # :nodoc:
        false
      end

      def number? # :nodoc:
        false
      end

      def binary? # :nodoc:
        false
      end

      def klass # :nodoc:
      end

      def changed?(old_value, new_value, _new_value_before_type_cast)
        old_value != new_value
      end

      def changed_in_place?(*)
        false
      end

      def ==(other)
        self.class == other.class &&
          precision == other.precision &&
          scale == other.scale &&
          limit == other.limit
      end

      private

      def type_cast(value)
        cast_value(value) unless value.nil?
      end

      def cast_value(value) # :doc:
        value
      end
    end
  end
end
