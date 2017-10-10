require 'date'
require 'bigdecimal'
require 'bigdecimal/util'
require 'active_record/type'
require 'active_support/core_ext/benchmark'
require 'active_record/connection_adapters/schema_cache'
require 'active_record/connection_adapters/abstract/schema_dumper'
require 'active_record/connection_adapters/abstract/schema_creation'
require 'monitor'
require 'arel/collectors/bind'
require 'arel/collectors/sql_string'

module ActiveRecord
  module ConnectionAdapters # :nodoc:
    extend ActiveSupport::Autoload

    autoload :Column
    autoload :ConnectionSpecification

    autoload_at 'active_record/connection_adapters/abstract/schema_definitions' do
      autoload :IndexDefinition
      autoload :ColumnDefinition
      autoload :ChangeColumnDefinition
      autoload :TableDefinition
      autoload :Table
      autoload :AlterTable
      autoload :TimestampDefaultDeprecation
    end

    autoload_at 'active_record/connection_adapters/abstract/connection_pool' do
      autoload :ConnectionHandler
      autoload :ConnectionManagement
    end

    autoload_under 'abstract' do
      autoload :SchemaStatements
      autoload :DatabaseStatements
      autoload :DatabaseLimits
      autoload :Quoting
      autoload :ConnectionPool
      autoload :QueryCache
      autoload :Savepoints
    end

    autoload_at 'active_record/connection_adapters/abstract/transaction' do
      autoload :TransactionManager
      autoload :NullTransaction
      autoload :RealTransaction
      autoload :SavepointTransaction
      autoload :TransactionState
    end

    class AbstractAdapter
      ADAPTER_NAME = 'Abstract'.freeze
      include Quoting, DatabaseStatements, SchemaStatements
      include DatabaseLimits
      include QueryCache
      include ActiveSupport::Callbacks
      include MonitorMixin
      include ColumnDumper

      SIMPLE_INT = /\A\d+\z/

      define_callbacks :checkout, :checkin

      attr_accessor :visitor, :pool
      attr_reader :schema_cache, :owner, :logger
      alias :in_use? :owner

      def self.type_cast_config_to_integer(config)
        if config =~ SIMPLE_INT
          config.to_i
        else
          config
        end
      end

      def self.type_cast_config_to_boolean(config)
        if config == "false"
          false
        else
          config
        end
      end

      attr_reader :prepared_statements

      def initialize(connection, logger = nil, pool = nil) #:nodoc:
        super()

        @connection          = connection
        @owner               = nil
        @instrumenter        = ActiveSupport::Notifications.instrumenter
        @logger              = logger
        @pool                = pool
        @schema_cache        = SchemaCache.new self
        @visitor             = nil
        @prepared_statements = false
      end

      class BindCollector < Arel::Collectors::Bind
        def compile(bvs, conn)
          super(bvs.map { |bv| conn.quote(*bv.reverse) })
        end
      end

      class SQLString < Arel::Collectors::SQLString
        def compile(bvs, conn)
          super(bvs)
        end
      end

      def collector
        if prepared_statements
          SQLString.new
        else
          BindCollector.new
        end
      end

      def valid_type?(type)
        true
      end

      def schema_creation
        SchemaCreation.new self
      end

      def lease
        synchronize do
          unless in_use?
            @owner = Thread.current
          end
        end
      end

      def schema_cache=(cache)
        cache.connection = self
        @schema_cache = cache
      end

      def expire
        @owner = nil
      end

      def unprepared_statement
        old_prepared_statements, @prepared_statements = @prepared_statements, false
        yield
      ensure
        @prepared_statements = old_prepared_statements
      end

      def adapter_name
        self.class::ADAPTER_NAME
      end

      def supports_migrations?
        false
      end

      def supports_primary_key?
        false
      end

      def supports_ddl_transactions?
        false
      end

      def supports_bulk_alter?
        false
      end

      def supports_savepoints?
        false
      end

      def prefetch_primary_key?(table_name = nil)
        false
      end

      def supports_index_sort_order?
        false
      end

      def supports_partial_index?
        false
      end

      def supports_explain?
        false
      end

      def supports_transaction_isolation?
        false
      end

      def supports_extensions?
        false
      end

      def supports_indexes_in_create?
        false
      end

      def supports_foreign_keys?
        false
      end

      def supports_views?
        false
      end

      def disable_extension(name)
      end

      def enable_extension(name)
      end

      def extensions
        []
      end

      def index_algorithms
        {}
      end


      def substitute_at(column, _unused = 0)
        Arel::Nodes::BindParam.new
      end


      def disable_referential_integrity
        yield
      end


      def active?
      end

      def reconnect!
        clear_cache!
        reset_transaction
      end

      def disconnect!
        clear_cache!
        reset_transaction
      end

      def reset!
      end

      def clear_cache!
      end

      def requires_reloading?
        false
      end

      def verify!(*ignored)
        reconnect! unless active?
      end

      def raw_connection
        @connection
      end

      def create_savepoint(name = nil)
      end

      def release_savepoint(name = nil)
      end

      def case_sensitive_modifier(node, table_attribute)
        node
      end

      def case_sensitive_comparison(table, attribute, column, value)
        table_attr = table[attribute]
        value = case_sensitive_modifier(value, table_attr) unless value.nil?
        table_attr.eq(value)
      end

      def case_insensitive_comparison(table, attribute, column, value)
        table[attribute].lower.eq(table.lower(value))
      end

      def current_savepoint_name
        current_transaction.savepoint_name
      end

      def close
        pool.checkin self
      end

      def type_map # :nodoc:
        @type_map ||= Type::TypeMap.new.tap do |mapping|
          initialize_type_map(mapping)
        end
      end

      def new_column(name, default, cast_type, sql_type = nil, null = true)
        Column.new(name, default, cast_type, sql_type, null)
      end

      def lookup_cast_type(sql_type) # :nodoc:
        type_map.lookup(sql_type)
      end

      def column_name_for_operation(operation, node) # :nodoc:
        visitor.accept(node, collector).value
      end

      protected

      def initialize_type_map(m) # :nodoc:
        register_class_with_limit m, %r(boolean)i,   Type::Boolean
        register_class_with_limit m, %r(char)i,      Type::String
        register_class_with_limit m, %r(binary)i,    Type::Binary
        register_class_with_limit m, %r(text)i,      Type::Text
        register_class_with_limit m, %r(date)i,      Type::Date
        register_class_with_limit m, %r(time)i,      Type::Time
        register_class_with_limit m, %r(datetime)i,  Type::DateTime
        register_class_with_limit m, %r(float)i,     Type::Float
        register_class_with_limit m, %r(int)i,       Type::Integer

        m.alias_type %r(blob)i,      'binary'
        m.alias_type %r(clob)i,      'text'
        m.alias_type %r(timestamp)i, 'datetime'
        m.alias_type %r(numeric)i,   'decimal'
        m.alias_type %r(number)i,    'decimal'
        m.alias_type %r(double)i,    'float'

        m.register_type(%r(decimal)i) do |sql_type|
          scale = extract_scale(sql_type)
          precision = extract_precision(sql_type)

          if scale == 0
            Type::DecimalWithoutScale.new(precision: precision)
          else
            Type::Decimal.new(precision: precision, scale: scale)
          end
        end
      end

      def reload_type_map # :nodoc:
        type_map.clear
        initialize_type_map(type_map)
      end

      def register_class_with_limit(mapping, key, klass) # :nodoc:
        mapping.register_type(key) do |*args|
          limit = extract_limit(args.last)
          klass.new(limit: limit)
        end
      end

      def extract_scale(sql_type) # :nodoc:
        case sql_type
          when /\((\d+)\)/ then 0
          when /\((\d+)(,(\d+))\)/ then $3.to_i
        end
      end

      def extract_precision(sql_type) # :nodoc:
        $1.to_i if sql_type =~ /\((\d+)(,\d+)?\)/
      end

      def extract_limit(sql_type) # :nodoc:
        case sql_type
        when /^bigint/i
          8
        when /\((.*)\)/
          $1.to_i
        end
      end

      def translate_exception_class(e, sql)
        begin
          message = "#{e.class.name}: #{e.message}: #{sql}"
        rescue Encoding::CompatibilityError
          message = "#{e.class.name}: #{e.message.force_encoding sql.encoding}: #{sql}"
        end

        @logger.error message if @logger
        exception = translate_exception(e, message)
        exception.set_backtrace e.backtrace
        exception
      end

      def log(sql, name = "SQL", binds = [], statement_name = nil)
        @instrumenter.instrument(
          "sql.active_record",
          :sql            => sql,
          :name           => name,
          :connection_id  => object_id,
          :statement_name => statement_name,
          :binds          => binds) { yield }
      rescue => e
        raise translate_exception_class(e, sql)
      end

      def translate_exception(exception, message)
        ActiveRecord::StatementInvalid.new(message, exception)
      end

      def without_prepared_statement?(binds)
        !prepared_statements || binds.empty?
      end

      def column_for(table_name, column_name) # :nodoc:
        column_name = column_name.to_s
        columns(table_name).detect { |c| c.name == column_name } ||
          raise(ActiveRecordError, "No such column: #{table_name}.#{column_name}")
      end
    end
  end
end
