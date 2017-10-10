require 'date'
require 'set'
require 'bigdecimal'
require 'bigdecimal/util'

module ActiveRecord
  module ConnectionAdapters #:nodoc:
    class IndexDefinition < Struct.new(:table, :name, :unique, :columns, :lengths, :orders, :where, :type, :using) #:nodoc:
    end

    class ColumnDefinition < Struct.new(:name, :type, :limit, :precision, :scale, :default, :null, :first, :after, :primary_key, :sql_type, :cast_type) #:nodoc:

      def primary_key?
        primary_key || type.to_sym == :primary_key
      end
    end

    class ChangeColumnDefinition < Struct.new(:column, :type, :options) #:nodoc:
    end

    class ForeignKeyDefinition < Struct.new(:from_table, :to_table, :options) #:nodoc:
      def name
        options[:name]
      end

      def column
        options[:column]
      end

      def primary_key
        options[:primary_key] || default_primary_key
      end

      def on_delete
        options[:on_delete]
      end

      def on_update
        options[:on_update]
      end

      def custom_primary_key?
        options[:primary_key] != default_primary_key
      end

      private
      def default_primary_key
        "id"
      end
    end

    module TimestampDefaultDeprecation # :nodoc:
      def emit_warning_if_null_unspecified(sym, options)
        return if options.key?(:null)

        ActiveSupport::Deprecation.warn(<<-MSG.squish)
          `##{sym}` was called without specifying an option for `null`. In Rails 5,
          this behavior will change to `null: false`. You should manually specify
         `null: true` to prevent the behavior of your existing migrations from changing.
        MSG
      end
    end

    class TableDefinition
      include TimestampDefaultDeprecation

      attr_accessor :indexes
      attr_reader :name, :temporary, :options, :as, :foreign_keys

      def initialize(types, name, temporary, options, as = nil)
        @columns_hash = {}
        @indexes = {}
        @foreign_keys = {}
        @native = types
        @temporary = temporary
        @options = options
        @as = as
        @name = name
      end

      def columns; @columns_hash.values; end

      def primary_key(name, type = :primary_key, options = {})
        column(name, type, options.merge(:primary_key => true))
      end

      def [](name)
        @columns_hash[name.to_s]
      end

      def column(name, type, options = {})
        name = name.to_s
        type = type.to_sym
        options = options.dup

        if @columns_hash[name] && @columns_hash[name].primary_key?
          raise ArgumentError, "you can't redefine the primary key column '#{name}'. To define a custom primary key, pass { id: false } to create_table."
        end

        index_options = options.delete(:index)
        index(name, index_options.is_a?(Hash) ? index_options : {}) if index_options
        @columns_hash[name] = new_column_definition(name, type, options)
        self
      end

      def remove_column(name)
        @columns_hash.delete name.to_s
      end

      [:string, :text, :integer, :bigint, :float, :decimal, :datetime, :timestamp, :time, :date, :binary, :boolean].each do |column_type|
        #nodyna <define_method-911> <DM MODERATE (array)>
        define_method column_type do |*args|
          options = args.extract_options!
          column_names = args
          column_names.each { |name| column(name, column_type, options) }
        end
      end

      def index(column_name, options = {})
        indexes[column_name] = options
      end

      def foreign_key(table_name, options = {}) # :nodoc:
        foreign_keys[table_name] = options
      end

      def timestamps(*args)
        options = args.extract_options!
        emit_warning_if_null_unspecified(:timestamps, options)
        column(:created_at, :datetime, options)
        column(:updated_at, :datetime, options)
      end

      def references(*args)
        options = args.extract_options!
        polymorphic = options.delete(:polymorphic)
        index_options = options.delete(:index)
        foreign_key_options = options.delete(:foreign_key)
        type = options.delete(:type) || :integer

        if polymorphic && foreign_key_options
          raise ArgumentError, "Cannot add a foreign key on a polymorphic relation"
        end

        args.each do |col|
          column("#{col}_id", type, options)
          column("#{col}_type", :string, polymorphic.is_a?(Hash) ? polymorphic : options) if polymorphic
          index(polymorphic ? %w(type id).map { |t| "#{col}_#{t}" } : "#{col}_id", index_options.is_a?(Hash) ? index_options : {}) if index_options
          if foreign_key_options
            to_table = Base.pluralize_table_names ? col.to_s.pluralize : col.to_s
            foreign_key(to_table, foreign_key_options.is_a?(Hash) ? foreign_key_options : {})
          end
        end
      end
      alias :belongs_to :references

      def new_column_definition(name, type, options) # :nodoc:
        type = aliased_types(type.to_s, type)
        column = create_column_definition name, type
        limit = options.fetch(:limit) do
          native[type][:limit] if native[type].is_a?(Hash)
        end

        column.limit       = limit
        column.precision   = options[:precision]
        column.scale       = options[:scale]
        column.default     = options[:default]
        column.null        = options[:null]
        column.first       = options[:first]
        column.after       = options[:after]
        column.primary_key = type == :primary_key || options[:primary_key]
        column
      end

      private
      def create_column_definition(name, type)
        ColumnDefinition.new name, type
      end

      def native
        @native
      end

      def aliased_types(name, fallback)
        'timestamp' == name ? :datetime : fallback
      end
    end

    class AlterTable # :nodoc:
      attr_reader :adds
      attr_reader :foreign_key_adds
      attr_reader :foreign_key_drops

      def initialize(td)
        @td   = td
        @adds = []
        @foreign_key_adds = []
        @foreign_key_drops = []
      end

      def name; @td.name; end

      def add_foreign_key(to_table, options)
        @foreign_key_adds << ForeignKeyDefinition.new(name, to_table, options)
      end

      def drop_foreign_key(name)
        @foreign_key_drops << name
      end

      def add_column(name, type, options)
        name = name.to_s
        type = type.to_sym
        @adds << @td.new_column_definition(name, type, options)
      end
    end

    class Table
      attr_reader :name

      def initialize(table_name, base)
        @name = table_name
        @base = base
      end

      def column(column_name, type, options = {})
        @base.add_column(name, column_name, type, options)
      end

      def column_exists?(column_name, type = nil, options = {})
        @base.column_exists?(name, column_name, type, options)
      end

      def index(column_name, options = {})
        @base.add_index(name, column_name, options)
      end

      def index_exists?(column_name, options = {})
        @base.index_exists?(name, column_name, options)
      end

      def rename_index(index_name, new_index_name)
        @base.rename_index(name, index_name, new_index_name)
      end

      def timestamps(options = {})
        @base.add_timestamps(name, options)
      end

      def change(column_name, type, options = {})
        @base.change_column(name, column_name, type, options)
      end

      def change_default(column_name, default)
        @base.change_column_default(name, column_name, default)
      end

      def remove(*column_names)
        @base.remove_columns(name, *column_names)
      end

      def remove_index(options = {})
        @base.remove_index(name, options)
      end

      def remove_timestamps(options = {})
        @base.remove_timestamps(name, options)
      end

      def rename(column_name, new_column_name)
        @base.rename_column(name, column_name, new_column_name)
      end

      def references(*args)
        options = args.extract_options!
        args.each do |ref_name|
          @base.add_reference(name, ref_name, options)
        end
      end
      alias :belongs_to :references

      def remove_references(*args)
        options = args.extract_options!
        args.each do |ref_name|
          @base.remove_reference(name, ref_name, options)
        end
      end
      alias :remove_belongs_to :remove_references

      [:string, :text, :integer, :float, :decimal, :datetime, :timestamp, :time, :date, :binary, :boolean].each do |column_type|
        #nodyna <define_method-912> <DM MODERATE (array)>
        define_method column_type do |*args|
          options = args.extract_options!
          args.each do |column_name|
            @base.add_column(name, column_name, column_type, options)
          end
        end
      end

      private
        def native
          @base.native_database_types
        end
    end
  end
end
