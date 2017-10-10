module ActiveRecord
  module ConnectionAdapters
    class SchemaCache
      attr_reader :version
      attr_accessor :connection

      def initialize(conn)
        @connection = conn

        @columns      = {}
        @columns_hash = {}
        @primary_keys = {}
        @tables       = {}
      end

      def primary_keys(table_name)
        @primary_keys[table_name] ||= table_exists?(table_name) ? connection.primary_key(table_name) : nil
      end

      def table_exists?(name)
        prepare_tables if @tables.empty?
        return @tables[name] if @tables.key? name

        @tables[name] = connection.table_exists?(name)
      end

      def add(table_name)
        if table_exists?(table_name)
          primary_keys(table_name)
          columns(table_name)
          columns_hash(table_name)
        end
      end

      def tables(name)
        @tables[name]
      end

      def columns(table_name)
        @columns[table_name] ||= connection.columns(table_name)
      end

      def columns_hash(table_name)
        @columns_hash[table_name] ||= Hash[columns(table_name).map { |col|
          [col.name, col]
        }]
      end

      def clear!
        @columns.clear
        @columns_hash.clear
        @primary_keys.clear
        @tables.clear
        @version = nil
      end

      def size
        [@columns, @columns_hash, @primary_keys, @tables].map { |x|
          x.size
        }.inject :+
      end

      def clear_table_cache!(table_name)
        @columns.delete table_name
        @columns_hash.delete table_name
        @primary_keys.delete table_name
        @tables.delete table_name
      end

      def marshal_dump
        @version = ActiveRecord::Migrator.current_version
        [@version, @columns, @columns_hash, @primary_keys, @tables]
      end

      def marshal_load(array)
        @version, @columns, @columns_hash, @primary_keys, @tables = array
      end

      private

        def prepare_tables
          connection.tables.each { |table| @tables[table] = true }
        end
    end
  end
end
