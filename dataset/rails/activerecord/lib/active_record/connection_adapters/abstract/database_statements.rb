module ActiveRecord
  module ConnectionAdapters # :nodoc:
    module DatabaseStatements
      def initialize
        super
        reset_transaction
      end

      def to_sql(arel, binds = [])
        if arel.respond_to?(:ast)
          collected = visitor.accept(arel.ast, collector)
          collected.compile(binds.dup, self)
        else
          arel
        end
      end

      def cacheable_query(arel) # :nodoc:
        if prepared_statements
          ActiveRecord::StatementCache.query visitor, arel.ast
        else
          ActiveRecord::StatementCache.partial_query visitor, arel.ast, collector
        end
      end

      def select_all(arel, name = nil, binds = [])
        arel, binds = binds_from_relation arel, binds
        select(to_sql(arel, binds), name, binds)
      end

      def select_one(arel, name = nil, binds = [])
        select_all(arel, name, binds).first
      end

      def select_value(arel, name = nil, binds = [])
        if result = select_one(arel, name, binds)
          result.values.first
        end
      end

      def select_values(arel, name = nil)
        arel, binds = binds_from_relation arel, []
        select_rows(to_sql(arel, binds), name, binds).map(&:first)
      end

      def select_rows(sql, name = nil, binds = [])
      end
      undef_method :select_rows

      def execute(sql, name = nil)
      end
      undef_method :execute

      def exec_query(sql, name = 'SQL', binds = [])
      end

      def exec_insert(sql, name, binds, pk = nil, sequence_name = nil)
        exec_query(sql, name, binds)
      end

      def exec_delete(sql, name, binds)
        exec_query(sql, name, binds)
      end

      def truncate(table_name, name = nil)
        raise NotImplementedError
      end

      def exec_update(sql, name, binds)
        exec_query(sql, name, binds)
      end

      def insert(arel, name = nil, pk = nil, id_value = nil, sequence_name = nil, binds = [])
        sql, binds = sql_for_insert(to_sql(arel, binds), pk, id_value, sequence_name, binds)
        value      = exec_insert(sql, name, binds, pk, sequence_name)
        id_value || last_inserted_id(value)
      end

      def update(arel, name = nil, binds = [])
        exec_update(to_sql(arel, binds), name, binds)
      end

      def delete(arel, name = nil, binds = [])
        exec_delete(to_sql(arel, binds), name, binds)
      end

      def supports_statement_cache?
        false
      end

      def transaction(options = {})
        options.assert_valid_keys :requires_new, :joinable, :isolation

        if !options[:requires_new] && current_transaction.joinable?
          if options[:isolation]
            raise ActiveRecord::TransactionIsolationError, "cannot set isolation when joining a transaction"
          end
          yield
        else
          transaction_manager.within_new_transaction(options) { yield }
        end
      rescue ActiveRecord::Rollback
      end

      attr_reader :transaction_manager #:nodoc:

      delegate :within_new_transaction, :open_transactions, :current_transaction, :begin_transaction, :commit_transaction, :rollback_transaction, to: :transaction_manager

      def transaction_open?
        current_transaction.open?
      end

      def reset_transaction #:nodoc:
        @transaction_manager = TransactionManager.new(self)
      end

      def add_transaction_record(record)
        current_transaction.add_record(record)
      end

      def transaction_state
        current_transaction.state
      end

      def begin_db_transaction()    end

      def transaction_isolation_levels
        {
          read_uncommitted: "READ UNCOMMITTED",
          read_committed:   "READ COMMITTED",
          repeatable_read:  "REPEATABLE READ",
          serializable:     "SERIALIZABLE"
        }
      end

      def begin_isolated_db_transaction(isolation)
        raise ActiveRecord::TransactionIsolationError, "adapter does not support setting transaction isolation"
      end

      def commit_db_transaction()   end

      def rollback_db_transaction
        exec_rollback_db_transaction
      end

      def exec_rollback_db_transaction() end #:nodoc:

      def rollback_to_savepoint(name = nil)
        exec_rollback_to_savepoint(name)
      end

      def exec_rollback_to_savepoint(name = nil) #:nodoc:
      end

      def default_sequence_name(table, column)
        nil
      end

      def reset_sequence!(table, column, sequence = nil)
      end

      def insert_fixture(fixture, table_name)
        columns = schema_cache.columns_hash(table_name)

        key_list   = []
        value_list = fixture.map do |name, value|
          key_list << quote_column_name(name)
          quote(value, columns[name])
        end

        execute "INSERT INTO #{quote_table_name(table_name)} (#{key_list.join(', ')}) VALUES (#{value_list.join(', ')})", 'Fixture Insert'
      end

      def empty_insert_statement_value
        "DEFAULT VALUES"
      end

      def sanitize_limit(limit)
        if limit.is_a?(Integer) || limit.is_a?(Arel::Nodes::SqlLiteral)
          limit
        elsif limit.to_s.include?(',')
          Arel.sql limit.to_s.split(',').map{ |i| Integer(i) }.join(',')
        else
          Integer(limit)
        end
      end

      def join_to_update(update, select) #:nodoc:
        key = update.key
        subselect = subquery_for(key, select)

        update.where key.in(subselect)
      end

      def join_to_delete(delete, select, key) #:nodoc:
        subselect = subquery_for(key, select)

        delete.where key.in(subselect)
      end

      protected

        def subquery_for(key, select)
          subselect = select.clone
          subselect.projections = [key]
          subselect
        end

        def select(sql, name = nil, binds = [])
          exec_query(sql, name, binds)
        end


        def insert_sql(sql, name = nil, pk = nil, id_value = nil, sequence_name = nil)
          execute(sql, name)
          id_value
        end

        def update_sql(sql, name = nil)
          execute(sql, name)
        end

        def delete_sql(sql, name = nil)
          update_sql(sql, name)
        end

        def sql_for_insert(sql, pk, id_value, sequence_name, binds)
          [sql, binds]
        end

        def last_inserted_id(result)
          row = result.rows.first
          row && row.first
        end

        def binds_from_relation(relation, binds)
          if relation.is_a?(Relation) && binds.empty?
            relation, binds = relation.arel, relation.bind_values
          end
          [relation, binds]
        end
    end
  end
end
