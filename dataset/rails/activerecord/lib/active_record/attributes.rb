module ActiveRecord
  module Attributes # :nodoc:
    extend ActiveSupport::Concern

    Type = ActiveRecord::Type

    included do
      class_attribute :user_provided_columns, instance_accessor: false # :internal:
      class_attribute :user_provided_defaults, instance_accessor: false # :internal:
      self.user_provided_columns = {}
      self.user_provided_defaults = {}

      delegate :persistable_attribute_names, to: :class
    end

    module ClassMethods # :nodoc:
      def attribute(name, cast_type, options = {})
        name = name.to_s
        clear_caches_calculated_from_columns
        self.user_provided_columns = user_provided_columns.merge(name => cast_type)

        if options.key?(:default)
          self.user_provided_defaults = user_provided_defaults.merge(name => options[:default])
        end
      end

      def columns
        @columns ||= add_user_provided_columns(connection.schema_cache.columns(table_name))
      end

      def columns_hash
        @columns_hash ||= Hash[columns.map { |c| [c.name, c] }]
      end

      def persistable_attribute_names # :nodoc:
        @persistable_attribute_names ||= connection.schema_cache.columns_hash(table_name).keys
      end

      def reset_column_information # :nodoc:
        super
        clear_caches_calculated_from_columns
      end

      private

      def add_user_provided_columns(schema_columns)
        existing_columns = schema_columns.map do |column|
          new_type = user_provided_columns[column.name]
          if new_type
            column.with_type(new_type)
          else
            column
          end
        end

        existing_column_names = existing_columns.map(&:name)
        new_columns = user_provided_columns.except(*existing_column_names).map do |(name, type)|
          connection.new_column(name, nil, type)
        end

        existing_columns + new_columns
      end

      def clear_caches_calculated_from_columns
        @attributes_builder = nil
        @column_names = nil
        @column_types = nil
        @columns = nil
        @columns_hash = nil
        @content_columns = nil
        @default_attributes = nil
        @persistable_attribute_names = nil
      end

      def raw_default_values
        super.merge(user_provided_defaults)
      end
    end
  end
end
