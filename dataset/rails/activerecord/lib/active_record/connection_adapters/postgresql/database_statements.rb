module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module DatabaseStatements
        def explain(arel, binds = [])
          sql = "EXPLAIN #{to_sql(arel, binds)}"
          ExplainPrettyPrinter.new.pp(exec_query(sql, 'EXPLAIN', binds))
        end

        class ExplainPrettyPrinter # :nodoc:
          def pp(result)
            header = result.columns.first
            lines  = result.rows.map(&:first)

            width = [header, *lines].map(&:length).max + 2

            pp = []

            pp << header.center(width).rstrip
            pp << '-' * width

            pp += lines.map {|line| " #{line}"}

            nrows = result.rows.length
            rows_label = nrows == 1 ? 'row' : 'rows'
            pp << "(#{nrows} #{rows_label})"

            pp.join("\n") + "\n"
          end
        end

        def select_value(arel, name = nil, binds = [])
          arel, binds = binds_from_relation arel, binds
          sql = to_sql(arel, binds)
          execute_and_clear(sql, name, binds) do |result|
            result.getvalue(0, 0) if result.ntuples > 0 && result.nfields > 0
          end
        end

        def select_values(arel, name = nil)
          arel, binds = binds_from_relation arel, []
          sql = to_sql(arel, binds)
          execute_and_clear(sql, name, binds) do |result|
            if result.nfields > 0
              result.column_values(0)
            else
              []
            end
          end
        end

        def select_rows(sql, name = nil, binds = [])
          execute_and_clear(sql, name, binds) do |result|
            result.values
          end
        end

        def insert_sql(sql, name = nil, pk = nil, id_value = nil, sequence_name = nil)
          unless pk
            table_ref = extract_table_ref_from_insert_sql(sql)
            pk = primary_key(table_ref) if table_ref
          end

          if pk && use_insert_returning?
            select_value("#{sql} RETURNING #{quote_column_name(pk)}")
          elsif pk
            super
            last_insert_id_value(sequence_name || default_sequence_name(table_ref, pk))
          else
            super
          end
        end

        def create
          super.insert
        end

        MONEY_COLUMN_TYPE_OID = 790 #:nodoc:
        BYTEA_COLUMN_TYPE_OID = 17 #:nodoc:

        def result_as_array(res) #:nodoc:
          ftypes = Array.new(res.nfields) do |i|
            [i, res.ftype(i)]
          end

          rows = res.values
          return rows unless ftypes.any? { |_, x|
            x == BYTEA_COLUMN_TYPE_OID || x == MONEY_COLUMN_TYPE_OID
          }

          typehash = ftypes.group_by { |_, type| type }
          binaries = typehash[BYTEA_COLUMN_TYPE_OID] || []
          monies   = typehash[MONEY_COLUMN_TYPE_OID] || []

          rows.each do |row|
            binaries.each do |index, _|
              row[index] = unescape_bytea(row[index])
            end

            monies.each do |index, _|
              data = row[index]
              case data
              when /^-?\D+[\d,]+\.\d{2}$/  # (1)
                data.gsub!(/[^-\d.]/, '')
              when /^-?\D+[\d.]+,\d{2}$/  # (2)
                data.gsub!(/[^-\d,]/, '').sub!(/,/, '.')
              end
            end
          end
        end

        def query(sql, name = nil) #:nodoc:
          log(sql, name) do
            result_as_array @connection.async_exec(sql)
          end
        end

        def execute(sql, name = nil)
          log(sql, name) do
            @connection.async_exec(sql)
          end
        end

        def exec_query(sql, name = 'SQL', binds = [])
          execute_and_clear(sql, name, binds) do |result|
            types = {}
            fields = result.fields
            fields.each_with_index do |fname, i|
              ftype = result.ftype i
              fmod  = result.fmod i
              types[fname] = get_oid_type(ftype, fmod, fname)
            end
            ActiveRecord::Result.new(fields, result.values, types)
          end
        end

        def exec_delete(sql, name = 'SQL', binds = [])
          execute_and_clear(sql, name, binds) {|result| result.cmd_tuples }
        end
        alias :exec_update :exec_delete

        def sql_for_insert(sql, pk, id_value, sequence_name, binds)
          unless pk
            table_ref = extract_table_ref_from_insert_sql(sql)
            pk = primary_key(table_ref) if table_ref
          end

          if pk && use_insert_returning?
            sql = "#{sql} RETURNING #{quote_column_name(pk)}"
          end

          [sql, binds]
        end

        def exec_insert(sql, name, binds, pk = nil, sequence_name = nil)
          val = exec_query(sql, name, binds)
          if !use_insert_returning? && pk
            unless sequence_name
              table_ref = extract_table_ref_from_insert_sql(sql)
              sequence_name = default_sequence_name(table_ref, pk)
              return val unless sequence_name
            end
            last_insert_id_result(sequence_name)
          else
            val
          end
        end

        def update_sql(sql, name = nil)
          super.cmd_tuples
        end

        def begin_db_transaction
          execute "BEGIN"
        end

        def begin_isolated_db_transaction(isolation)
          begin_db_transaction
          execute "SET TRANSACTION ISOLATION LEVEL #{transaction_isolation_levels.fetch(isolation)}"
        end

        def commit_db_transaction
          execute "COMMIT"
        end

        def exec_rollback_db_transaction
          execute "ROLLBACK"
        end
      end
    end
  end
end
