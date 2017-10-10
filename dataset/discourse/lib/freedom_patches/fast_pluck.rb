
require_dependency 'sql_builder'

class ActiveRecord::Relation


  class ::ActiveRecord::ConnectionAdapters::PostgreSQLAdapter
    if Rails.version >= "4.2.0"
      def select_raw(arel, name = nil, binds = [], &block)
        arel, binds = binds_from_relation arel, binds
        sql = to_sql(arel, binds)
        execute_and_clear(sql, name, binds, &block)
      end
    else

      def select_raw(arel, name = nil, binds = [], &block)
        arel, binds = binds_from_relation arel, binds
        sql = to_sql(arel, binds)

        result = without_prepared_statement?(binds) ? exec_no_cache(sql, 'SQL', binds) :
                                                        exec_cache(sql, 'SQL', binds)
        yield result, nil
      end
    end
  end

  def pluck(*cols)

    conn = ActiveRecord::Base.connection
    relation = self

    cols.map! do |column_name|
      if column_name.is_a?(Symbol) && attribute_alias?(column_name)
        attribute_alias(column_name)
      else
        column_name.to_s
      end
    end


    if has_include?(cols.first)
      construct_relation_for_association_calculations.pluck(*cols)
    else
      relation = spawn

      relation.select_values = cols.map { |cn|
        columns_hash.key?(cn) ? arel_table[cn] : cn
      }

      conn.select_raw(relation) do |result,_|
        result.type_map = SqlBuilder.pg_type_map
        result.nfields == 1 ? result.column_values(0) : result.values
      end

    end
  end
end

