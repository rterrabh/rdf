require 'active_record/connection_adapters/abstract_mysql_adapter'

gem 'mysql2', '~> 0.3.13'
require 'mysql2'

module ActiveRecord
  module ConnectionHandling # :nodoc:
    def mysql2_connection(config)
      config = config.symbolize_keys

      config[:username] = 'root' if config[:username].nil?

      if Mysql2::Client.const_defined? :FOUND_ROWS
        config[:flags] = Mysql2::Client::FOUND_ROWS
      end

      client = Mysql2::Client.new(config)
      options = [config[:host], config[:username], config[:password], config[:database], config[:port], config[:socket], 0]
      ConnectionAdapters::Mysql2Adapter.new(client, logger, options, config)
    rescue Mysql2::Error => error
      if error.message.include?("Unknown database")
        raise ActiveRecord::NoDatabaseError.new(error.message, error)
      else
        raise
      end
    end
  end

  module ConnectionAdapters
    class Mysql2Adapter < AbstractMysqlAdapter
      ADAPTER_NAME = 'Mysql2'.freeze

      def initialize(connection, logger, connection_options, config)
        super
        @prepared_statements = false
        configure_connection
      end

      MAX_INDEX_LENGTH_FOR_UTF8MB4 = 191
      def initialize_schema_migrations_table
        if charset == 'utf8mb4'
          ActiveRecord::SchemaMigration.create_table(MAX_INDEX_LENGTH_FOR_UTF8MB4)
        else
          ActiveRecord::SchemaMigration.create_table
        end
      end

      def supports_explain?
        true
      end


      def each_hash(result) # :nodoc:
        if block_given?
          result.each(:as => :hash, :symbolize_keys => true) do |row|
            yield row
          end
        else
          to_enum(:each_hash, result)
        end
      end

      def error_number(exception)
        exception.error_number if exception.respond_to?(:error_number)
      end


      def quote_string(string)
        @connection.escape(string)
      end

      def quoted_date(value)
        if value.acts_like?(:time) && value.respond_to?(:usec)
          "#{super}.#{sprintf("%06d", value.usec)}"
        else
          super
        end
      end


      def active?
        return false unless @connection
        @connection.ping
      end

      def reconnect!
        super
        disconnect!
        connect
      end
      alias :reset! :reconnect!

      def disconnect!
        super
        unless @connection.nil?
          @connection.close
          @connection = nil
        end
      end


      def explain(arel, binds = [])
        sql     = "EXPLAIN #{to_sql(arel, binds.dup)}"
        start   = Time.now
        result  = exec_query(sql, 'EXPLAIN', binds)
        elapsed = Time.now - start

        ExplainPrettyPrinter.new.pp(result, elapsed)
      end

      class ExplainPrettyPrinter # :nodoc:
        def pp(result, elapsed)
          widths    = compute_column_widths(result)
          separator = build_separator(widths)

          pp = []

          pp << separator
          pp << build_cells(result.columns, widths)
          pp << separator

          result.rows.each do |row|
            pp << build_cells(row, widths)
          end

          pp << separator
          pp << build_footer(result.rows.length, elapsed)

          pp.join("\n") + "\n"
        end

        private

        def compute_column_widths(result)
          [].tap do |widths|
            result.columns.each_with_index do |column, i|
              cells_in_column = [column] + result.rows.map {|r| r[i].nil? ? 'NULL' : r[i].to_s}
              widths << cells_in_column.map(&:length).max
            end
          end
        end

        def build_separator(widths)
          padding = 1
          '+' + widths.map {|w| '-' * (w + (padding*2))}.join('+') + '+'
        end

        def build_cells(items, widths)
          cells = []
          items.each_with_index do |item, i|
            item = 'NULL' if item.nil?
            justifier = item.is_a?(Numeric) ? 'rjust' : 'ljust'
            #nodyna <send-920> <SD TRIVIAL (public methods)>
            cells << item.to_s.send(justifier, widths[i])
          end
          '| ' + cells.join(' | ') + ' |'
        end

        def build_footer(nrows, elapsed)
          rows_label = nrows == 1 ? 'row' : 'rows'
          "#{nrows} #{rows_label} in set (%.2f sec)" % elapsed
        end
      end


      def select_rows(sql, name = nil, binds = [])
        execute(sql, name).to_a
      end

      def execute(sql, name = nil)
        if @connection
          @connection.query_options[:database_timezone] = ActiveRecord::Base.default_timezone
        end

        super
      end

      def exec_query(sql, name = 'SQL', binds = [])
        result = execute(sql, name)
        ActiveRecord::Result.new(result.fields, result.to_a)
      end

      alias exec_without_stmt exec_query

      def insert_sql(sql, name = nil, pk = nil, id_value = nil, sequence_name = nil)
        super
        id_value || @connection.last_id
      end
      alias :create :insert_sql

      def exec_insert(sql, name, binds, pk = nil, sequence_name = nil)
        execute to_sql(sql, binds), name
      end

      def exec_delete(sql, name, binds)
        execute to_sql(sql, binds), name
        @connection.affected_rows
      end
      alias :exec_update :exec_delete

      def last_inserted_id(result)
        @connection.last_id
      end

      private

      def connect
        @connection = Mysql2::Client.new(@config)
        configure_connection
      end

      def configure_connection
        @connection.query_options.merge!(:as => :array)
        super
      end

      def full_version
        @full_version ||= @connection.server_info[:version]
      end

      def set_field_encoding field_name
        field_name
      end
    end
  end
end
