module ActiveRecord
  module Calculations
    def count(column_name = nil, options = {})
      column_name, options = nil, column_name if column_name.is_a?(Hash)
      calculate(:count, column_name, options)
    end

    def average(column_name, options = {})
      calculate(:average, column_name, options)
    end

    def minimum(column_name, options = {})
      calculate(:minimum, column_name, options)
    end

    def maximum(column_name, options = {})
      calculate(:maximum, column_name, options)
    end

    def sum(*args)
      calculate(:sum, *args)
    end

    def calculate(operation, column_name, options = {})
      if column_name.is_a?(Symbol) && attribute_alias?(column_name)
        column_name = attribute_alias(column_name)
      end

      if has_include?(column_name)
        construct_relation_for_association_calculations.calculate(operation, column_name, options)
      else
        perform_calculation(operation, column_name, options)
      end
    end

    def pluck(*column_names)
      column_names.map! do |column_name|
        if column_name.is_a?(Symbol) && attribute_alias?(column_name)
          attribute_alias(column_name)
        else
          column_name.to_s
        end
      end

      if has_include?(column_names.first)
        construct_relation_for_association_calculations.pluck(*column_names)
      else
        relation = spawn
        relation.select_values = column_names.map { |cn|
          columns_hash.key?(cn) ? arel_table[cn] : cn
        }
        result = klass.connection.select_all(relation.arel, nil, relation.arel.bind_values + bind_values)
        result.cast_values(klass.column_types)
      end
    end

    def ids
      pluck primary_key
    end

    private

    def has_include?(column_name)
      eager_loading? || (includes_values.present? && ((column_name && column_name != :all) || references_eager_loaded_tables?))
    end

    def perform_calculation(operation, column_name, options = {})
      operation = operation.to_s.downcase

      distinct = self.distinct_value

      if operation == "count"
        column_name ||= select_for_count

        unless arel.ast.grep(Arel::Nodes::OuterJoin).empty?
          distinct = true
        end

        column_name = primary_key if column_name == :all && distinct
        distinct = nil if column_name =~ /\s*DISTINCT[\s(]+/i
      end

      if group_values.any?
        execute_grouped_calculation(operation, column_name, distinct)
      else
        execute_simple_calculation(operation, column_name, distinct)
      end
    end

    def aggregate_column(column_name)
      if @klass.column_names.include?(column_name.to_s)
        Arel::Attribute.new(@klass.unscoped.table, column_name)
      else
        Arel.sql(column_name == :all ? "*" : column_name.to_s)
      end
    end

    def operation_over_aggregate_column(column, operation, distinct)
      #nodyna <send-833> <SD COMPLEX (change-prone variables)>
      operation == 'count' ? column.count(distinct) : column.send(operation)
    end

    def execute_simple_calculation(operation, column_name, distinct) #:nodoc:
      relation = unscope(:order)

      column_alias = column_name

      bind_values = nil

      if operation == "count" && (relation.limit_value || relation.offset_value)
        return 0 if relation.limit_value == 0

        query_builder = build_count_subquery(relation, column_name, distinct)
        bind_values = query_builder.bind_values + relation.bind_values
      else
        column = aggregate_column(column_name)

        select_value = operation_over_aggregate_column(column, operation, distinct)

        column_alias = select_value.alias
        column_alias ||= @klass.connection.column_name_for_operation(operation, select_value)
        relation.select_values = [select_value]

        query_builder = relation.arel
        bind_values = query_builder.bind_values + relation.bind_values
      end

      result = @klass.connection.select_all(query_builder, nil, bind_values)
      row    = result.first
      value  = row && row.values.first
      column = result.column_types.fetch(column_alias) do
        type_for(column_name)
      end

      type_cast_calculated_value(value, column, operation)
    end

    def execute_grouped_calculation(operation, column_name, distinct) #:nodoc:
      group_attrs = group_values

      if group_attrs.first.respond_to?(:to_sym)
        association  = @klass._reflect_on_association(group_attrs.first)
        associated   = group_attrs.size == 1 && association && association.belongs_to? # only count belongs_to associations
        group_fields = Array(associated ? association.foreign_key : group_attrs)
      else
        group_fields = group_attrs
      end

      group_aliases = group_fields.map { |field|
        column_alias_for(field)
      }
      group_columns = group_aliases.zip(group_fields).map { |aliaz,field|
        [aliaz, field]
      }

      group = group_fields

      if operation == 'count' && column_name == :all
        aggregate_alias = 'count_all'
      else
        aggregate_alias = column_alias_for([operation, column_name].join(' '))
      end

      select_values = [
        operation_over_aggregate_column(
          aggregate_column(column_name),
          operation,
          distinct).as(aggregate_alias)
      ]
      select_values += select_values unless having_values.empty?

      select_values.concat group_fields.zip(group_aliases).map { |field,aliaz|
        if field.respond_to?(:as)
          field.as(aliaz)
        else
          "#{field} AS #{aliaz}"
        end
      }

      relation = except(:group)
      relation.group_values  = group
      relation.select_values = select_values

      calculated_data = @klass.connection.select_all(relation, nil, relation.arel.bind_values + bind_values)

      if association
        key_ids     = calculated_data.collect { |row| row[group_aliases.first] }
        key_records = association.klass.base_class.find(key_ids)
        key_records = Hash[key_records.map { |r| [r.id, r] }]
      end

      Hash[calculated_data.map do |row|
        key = group_columns.map { |aliaz, col_name|
          column = calculated_data.column_types.fetch(aliaz) do
            type_for(col_name)
          end
          type_cast_calculated_value(row[aliaz], column)
        }
        key = key.first if key.size == 1
        key = key_records[key] if associated

        column_type = calculated_data.column_types.fetch(aggregate_alias) { type_for(column_name) }
        [key, type_cast_calculated_value(row[aggregate_alias], column_type, operation)]
      end]
    end

    def column_alias_for(keys)
      if keys.respond_to? :name
        keys = "#{keys.relation.name}.#{keys.name}"
      end

      table_name = keys.to_s.downcase
      table_name.gsub!(/\*/, 'all')
      table_name.gsub!(/\W+/, ' ')
      table_name.strip!
      table_name.gsub!(/ +/, '_')

      @klass.connection.table_alias_for(table_name)
    end

    def type_for(field)
      field_name = field.respond_to?(:name) ? field.name.to_s : field.to_s.split('.').last
      @klass.type_for_attribute(field_name)
    end

    def type_cast_calculated_value(value, type, operation = nil)
      case operation
        when 'count'   then value.to_i
        when 'sum'     then type.type_cast_from_database(value || 0)
        when 'average' then value.respond_to?(:to_d) ? value.to_d : value
        else type.type_cast_from_database(value)
      end
    end

    def select_for_count
      if select_values.present?
        select_values.join(", ")
      else
        :all
      end
    end

    def build_count_subquery(relation, column_name, distinct)
      column_alias = Arel.sql('count_column')
      subquery_alias = Arel.sql('subquery_for_count')

      aliased_column = aggregate_column(column_name == :all ? 1 : column_name).as(column_alias)
      relation.select_values = [aliased_column]
      arel = relation.arel
      subquery = arel.as(subquery_alias)

      sm = Arel::SelectManager.new relation.engine
      sm.bind_values = arel.bind_values
      select_value = operation_over_aggregate_column(column_alias, 'count', distinct)
      sm.project(select_value).from(subquery)
    end
  end
end
