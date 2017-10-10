module ActiveRecord
  module ModelSchema
    extend ActiveSupport::Concern

    included do
      mattr_accessor :primary_key_prefix_type, instance_writer: false

      class_attribute :table_name_prefix, instance_writer: false
      self.table_name_prefix = ""

      class_attribute :table_name_suffix, instance_writer: false
      self.table_name_suffix = ""

      class_attribute :schema_migrations_table_name, instance_accessor: false
      self.schema_migrations_table_name = "schema_migrations"

      class_attribute :pluralize_table_names, instance_writer: false
      self.pluralize_table_names = true

      self.inheritance_column = 'type'

      delegate :type_for_attribute, to: :class
    end

    def self.derive_join_table_name(first_table, second_table) # :nodoc:
      [first_table.to_s, second_table.to_s].sort.join("\0").gsub(/^(.*_)(.+)\0\1(.+)/, '\1\2_\3').tr("\0", "_")
    end

    module ClassMethods
      def table_name
        reset_table_name unless defined?(@table_name)
        @table_name
      end

      def table_name=(value)
        value = value && value.to_s

        if defined?(@table_name)
          return if value == @table_name
          reset_column_information if connected?
        end

        @table_name        = value
        @quoted_table_name = nil
        @arel_table        = nil
        @sequence_name     = nil unless defined?(@explicit_sequence_name) && @explicit_sequence_name
        @relation          = Relation.create(self, arel_table)
      end

      def quoted_table_name
        @quoted_table_name ||= connection.quote_table_name(table_name)
      end

      def reset_table_name #:nodoc:
        self.table_name = if abstract_class?
          superclass == Base ? nil : superclass.table_name
        elsif superclass.abstract_class?
          superclass.table_name || compute_table_name
        else
          compute_table_name
        end
      end

      def full_table_name_prefix #:nodoc:
        (parents.detect{ |p| p.respond_to?(:table_name_prefix) } || self).table_name_prefix
      end

      def full_table_name_suffix #:nodoc:
        (parents.detect {|p| p.respond_to?(:table_name_suffix) } || self).table_name_suffix
      end

      def inheritance_column
        (@inheritance_column ||= nil) || superclass.inheritance_column
      end

      def inheritance_column=(value)
        @inheritance_column = value.to_s
        @explicit_inheritance_column = true
      end

      def sequence_name
        if base_class == self
          @sequence_name ||= reset_sequence_name
        else
          (@sequence_name ||= nil) || base_class.sequence_name
        end
      end

      def reset_sequence_name #:nodoc:
        @explicit_sequence_name = false
        @sequence_name          = connection.default_sequence_name(table_name, primary_key)
      end

      def sequence_name=(value)
        @sequence_name          = value.to_s
        @explicit_sequence_name = true
      end

      def table_exists?
        connection.schema_cache.table_exists?(table_name)
      end

      def attributes_builder # :nodoc:
        @attributes_builder ||= AttributeSet::Builder.new(column_types, primary_key)
      end

      def column_types # :nodoc:
        @column_types ||= columns_hash.transform_values(&:cast_type).tap do |h|
          h.default = Type::Value.new
        end
      end

      def type_for_attribute(attr_name) # :nodoc:
        column_types[attr_name]
      end

      def column_defaults
        _default_attributes.to_hash
      end

      def _default_attributes # :nodoc:
        @default_attributes ||= attributes_builder.build_from_database(
          raw_default_values)
      end

      def column_names
        @column_names ||= columns.map { |column| column.name }
      end

      def content_columns
        @content_columns ||= columns.reject { |c| c.name == primary_key || c.name =~ /(_id|_count)$/ || c.name == inheritance_column }
      end

      def reset_column_information
        connection.clear_cache!
        undefine_attribute_methods
        connection.schema_cache.clear_table_cache!(table_name)

        @arel_engine        = nil
        @column_names       = nil
        @column_types       = nil
        @content_columns    = nil
        @default_attributes = nil
        @inheritance_column = nil unless defined?(@explicit_inheritance_column) && @explicit_inheritance_column
        @relation           = nil
      end

      private

      def undecorated_table_name(class_name = base_class.name)
        table_name = class_name.to_s.demodulize.underscore
        pluralize_table_names ? table_name.pluralize : table_name
      end

      def compute_table_name
        base = base_class
        if self == base
          if parent < Base && !parent.abstract_class?
            contained = parent.table_name
            contained = contained.singularize if parent.pluralize_table_names
            contained += '_'
          end

          "#{full_table_name_prefix}#{contained}#{undecorated_table_name(name)}#{full_table_name_suffix}"
        else
          base.table_name
        end
      end

      def raw_default_values
        columns_hash.transform_values(&:default)
      end
    end
  end
end
