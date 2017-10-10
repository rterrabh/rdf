require 'set'

module ActiveRecord
  module ConnectionAdapters
    class Column
      TRUE_VALUES = [true, 1, '1', 't', 'T', 'true', 'TRUE', 'on', 'ON'].to_set
      FALSE_VALUES = [false, 0, '0', 'f', 'F', 'false', 'FALSE', 'off', 'OFF'].to_set

      module Format
        ISO_DATE = /\A(\d{4})-(\d\d)-(\d\d)\z/
        ISO_DATETIME = /\A(\d{4})-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)(\.\d+)?\z/
      end

      attr_reader :name, :cast_type, :null, :sql_type, :default, :default_function

      delegate :type, :precision, :scale, :limit, :klass, :accessor,
        :text?, :number?, :binary?, :changed?,
        :type_cast_from_user, :type_cast_from_database, :type_cast_for_database,
        :type_cast_for_schema,
        to: :cast_type

      def initialize(name, default, cast_type, sql_type = nil, null = true)
        @name             = name
        @cast_type        = cast_type
        @sql_type         = sql_type
        @null             = null
        @default          = default
        @default_function = nil
      end

      def has_default?
        !default.nil?
      end

      def human_name
        Base.human_attribute_name(@name)
      end

      def with_type(type)
        dup.tap do |clone|
          #nodyna <instance_variable_set-908> <not yet classified>
          clone.instance_variable_set('@cast_type', type)
        end
      end

      def ==(other)
        other.name == name &&
          other.default == default &&
          other.cast_type == cast_type &&
          other.sql_type == sql_type &&
          other.null == null &&
          other.default_function == default_function
      end
      alias :eql? :==

      def hash
        attributes_for_hash.hash
      end

      private

      def attributes_for_hash
        [self.class, name, default, cast_type, sql_type, null, default_function]
      end
    end
  end
end
