module ActiveRecord
  module Sanitization
    extend ActiveSupport::Concern

    module ClassMethods
      def quote_value(value, column) #:nodoc:
        connection.quote(value, column)
      end

      def sanitize(object) #:nodoc:
        connection.quote(object)
      end

      protected

      def sanitize_sql_for_conditions(condition, table_name = self.table_name)
        return nil if condition.blank?

        case condition
        when Array; sanitize_sql_array(condition)
        when Hash;  sanitize_sql_hash_for_conditions(condition, table_name)
        else        condition
        end
      end
      alias_method :sanitize_sql, :sanitize_sql_for_conditions
      alias_method :sanitize_conditions, :sanitize_sql

      def sanitize_sql_for_assignment(assignments, default_table_name = self.table_name)
        case assignments
        when Array; sanitize_sql_array(assignments)
        when Hash;  sanitize_sql_hash_for_assignment(assignments, default_table_name)
        else        assignments
        end
      end

      def expand_hash_conditions_for_aggregates(attrs)
        expanded_attrs = {}
        attrs.each do |attr, value|
          if aggregation = reflect_on_aggregation(attr.to_sym)
            mapping = aggregation.mapping
            mapping.each do |field_attr, aggregate_attr|
              if mapping.size == 1 && !value.respond_to?(aggregate_attr)
                expanded_attrs[field_attr] = value
              else
                #nodyna <send-939> <SD COMPLEX (change-prone variables)>
                expanded_attrs[field_attr] = value.send(aggregate_attr)
              end
            end
          else
            expanded_attrs[attr] = value
          end
        end
        expanded_attrs
      end

      def sanitize_sql_hash_for_conditions(attrs, default_table_name = self.table_name)
        ActiveSupport::Deprecation.warn(<<-EOWARN)
sanitize_sql_hash_for_conditions is deprecated, and will be removed in Rails 5.0
        EOWARN
        attrs = PredicateBuilder.resolve_column_aliases self, attrs
        attrs = expand_hash_conditions_for_aggregates(attrs)

        table = Arel::Table.new(table_name, arel_engine).alias(default_table_name)
        PredicateBuilder.build_from_hash(self, attrs, table).map { |b|
          connection.visitor.compile b
        }.join(' AND ')
      end
      alias_method :sanitize_sql_hash, :sanitize_sql_hash_for_conditions

      def sanitize_sql_hash_for_assignment(attrs, table)
        c = connection
        attrs.map do |attr, value|
          "#{c.quote_table_name_for_assignment(table, attr)} = #{quote_bound_value(value, c, columns_hash[attr.to_s])}"
        end.join(', ')
      end

      def sanitize_sql_like(string, escape_character = "\\")
        pattern = Regexp.union(escape_character, "%", "_")
        string.gsub(pattern) { |x| [escape_character, x].join }
      end

      def sanitize_sql_array(ary)
        statement, *values = ary
        if values.first.is_a?(Hash) && statement =~ /:\w+/
          replace_named_bind_variables(statement, values.first)
        elsif statement.include?('?')
          replace_bind_variables(statement, values)
        elsif statement.blank?
          statement
        else
          statement % values.collect { |value| connection.quote_string(value.to_s) }
        end
      end

      def replace_bind_variables(statement, values) #:nodoc:
        raise_if_bind_arity_mismatch(statement, statement.count('?'), values.size)
        bound = values.dup
        c = connection
        statement.gsub(/\?/) do
          replace_bind_variable(bound.shift, c)
        end
      end

      def replace_bind_variable(value, c = connection) #:nodoc:
        if ActiveRecord::Relation === value
          value.to_sql
        else
          quote_bound_value(value, c)
        end
      end

      def replace_named_bind_variables(statement, bind_vars) #:nodoc:
        statement.gsub(/(:?):([a-zA-Z]\w*)/) do
          if $1 == ':' # skip postgresql casts
            $& # return the whole match
          elsif bind_vars.include?(match = $2.to_sym)
            replace_bind_variable(bind_vars[match])
          else
            raise PreparedStatementInvalid, "missing value for :#{match} in #{statement}"
          end
        end
      end

      def quote_bound_value(value, c = connection, column = nil) #:nodoc:
        if column
          c.quote(value, column)
        elsif value.respond_to?(:map) && !value.acts_like?(:string)
          if value.respond_to?(:empty?) && value.empty?
            c.quote(nil)
          else
            value.map { |v| c.quote(v) }.join(',')
          end
        else
          c.quote(value)
        end
      end

      def raise_if_bind_arity_mismatch(statement, expected, provided) #:nodoc:
        unless expected == provided
          raise PreparedStatementInvalid, "wrong number of bind variables (#{provided} for #{expected}) in: #{statement}"
        end
      end
    end

    def quoted_id
      self.class.quote_value(id, column_for_attribute(self.class.primary_key))
    end
  end
end
