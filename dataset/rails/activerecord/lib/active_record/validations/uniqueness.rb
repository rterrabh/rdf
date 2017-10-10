module ActiveRecord
  module Validations
    class UniquenessValidator < ActiveModel::EachValidator # :nodoc:
      def initialize(options)
        if options[:conditions] && !options[:conditions].respond_to?(:call)
          raise ArgumentError, "#{options[:conditions]} was passed as :conditions but is not callable. " \
                               "Pass a callable instead: `conditions: -> { where(approved: true) }`"
        end
        super({ case_sensitive: true }.merge!(options))
        @klass = options[:class]
      end

      def validate_each(record, attribute, value)
        finder_class = find_finder_class_for(record)
        table = finder_class.arel_table
        value = map_enum_attribute(finder_class, attribute, value)

        begin
          relation = build_relation(finder_class, table, attribute, value)
          relation = relation.and(table[finder_class.primary_key.to_sym].not_eq(record.id)) if record.persisted?
          relation = scope_relation(record, table, relation)
          relation = finder_class.unscoped.where(relation)
          relation = relation.merge(options[:conditions]) if options[:conditions]
        rescue RangeError
          relation = finder_class.none
        end

        if relation.exists?
          error_options = options.except(:case_sensitive, :scope, :conditions)
          error_options[:value] = value

          record.errors.add(attribute, :taken, error_options)
        end
      end

    protected
      def find_finder_class_for(record) #:nodoc:
        class_hierarchy = [record.class]

        while class_hierarchy.first != @klass
          class_hierarchy.unshift(class_hierarchy.first.superclass)
        end

        class_hierarchy.detect { |klass| !klass.abstract_class? }
      end

      def build_relation(klass, table, attribute, value) #:nodoc:
        if reflection = klass._reflect_on_association(attribute)
          attribute = reflection.foreign_key
          value = value.attributes[reflection.klass.primary_key] unless value.nil?
        end

        attribute_name = attribute.to_s

        if klass.attribute_aliases[attribute_name]
          attribute = klass.attribute_aliases[attribute_name]
          attribute_name = attribute.to_s
        end

        column = klass.columns_hash[attribute_name]
        value  = klass.connection.type_cast(value, column)
        if value.is_a?(String) && column.limit
          value = value.to_s[0, column.limit]
        end

        if !options[:case_sensitive] && value && column.text?
          klass.connection.case_insensitive_comparison(table, attribute, column, value)
        else
          klass.connection.case_sensitive_comparison(table, attribute, column, value)
        end
      end

      def scope_relation(record, table, relation)
        Array(options[:scope]).each do |scope_item|
          if reflection = record.class._reflect_on_association(scope_item)
            #nodyna <send-810> <SD COMPLEX (change-prone variables)>
            scope_value = record.send(reflection.foreign_key)
            scope_item  = reflection.foreign_key
          else
            scope_value = record._read_attribute(scope_item)
          end
          relation = relation.and(table[scope_item].eq(scope_value))
        end

        relation
      end

      def map_enum_attribute(klass, attribute, value)
        mapping = klass.defined_enums[attribute.to_s]
        value = mapping[value] if value && mapping
        value
      end
    end

    module ClassMethods
      def validates_uniqueness_of(*attr_names)
        validates_with UniquenessValidator, _merge_attributes(attr_names)
      end
    end
  end
end
