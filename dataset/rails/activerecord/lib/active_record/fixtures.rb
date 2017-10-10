require 'erb'
require 'yaml'
require 'zlib'
require 'active_support/dependencies'
require 'active_support/core_ext/digest/uuid'
require 'active_record/fixture_set/file'
require 'active_record/errors'

module ActiveRecord
  class FixtureClassNotFound < ActiveRecord::ActiveRecordError #:nodoc:
  end

  class FixtureSet

    MAX_ID = 2 ** 30 - 1

    @@all_cached_fixtures = Hash.new { |h,k| h[k] = {} }

    def self.default_fixture_model_name(fixture_set_name, config = ActiveRecord::Base) # :nodoc:
      config.pluralize_table_names ?
        fixture_set_name.singularize.camelize :
        fixture_set_name.camelize
    end

    def self.default_fixture_table_name(fixture_set_name, config = ActiveRecord::Base) # :nodoc:
       "#{ config.table_name_prefix }"\
       "#{ fixture_set_name.tr('/', '_') }"\
       "#{ config.table_name_suffix }".to_sym
    end

    def self.reset_cache
      @@all_cached_fixtures.clear
    end

    def self.cache_for_connection(connection)
      @@all_cached_fixtures[connection]
    end

    def self.fixture_is_cached?(connection, table_name)
      cache_for_connection(connection)[table_name]
    end

    def self.cached_fixtures(connection, keys_to_fetch = nil)
      if keys_to_fetch
        cache_for_connection(connection).values_at(*keys_to_fetch)
      else
        cache_for_connection(connection).values
      end
    end

    def self.cache_fixtures(connection, fixtures_map)
      cache_for_connection(connection).update(fixtures_map)
    end

    def self.instantiate_fixtures(object, fixture_set, load_instances = true)
      if load_instances
        fixture_set.each do |fixture_name, fixture|
          begin
            #nodyna <instance_variable_set-793> <not yet classified>
            object.instance_variable_set "@#{fixture_name}", fixture.find
          rescue FixtureClassNotFound
            nil
          end
        end
      end
    end

    def self.instantiate_all_loaded_fixtures(object, load_instances = true)
      all_loaded_fixtures.each_value do |fixture_set|
        instantiate_fixtures(object, fixture_set, load_instances)
      end
    end

    cattr_accessor :all_loaded_fixtures
    self.all_loaded_fixtures = {}

    class ClassCache
      def initialize(class_names, config)
        @class_names = class_names.stringify_keys
        @config      = config

        @class_names.delete_if { |klass_name, klass| !insert_class(@class_names, klass_name, klass) }
      end

      def [](fs_name)
        @class_names.fetch(fs_name) {
          klass = default_fixture_model(fs_name, @config).safe_constantize
          insert_class(@class_names, fs_name, klass)
        }
      end

      private

      def insert_class(class_names, name, klass)
        if klass && klass < ActiveRecord::Base
          class_names[name] = klass
        else
          class_names[name] = nil
        end
      end

      def default_fixture_model(fs_name, config)
        ActiveRecord::FixtureSet.default_fixture_model_name(fs_name, config)
      end
    end

    def self.create_fixtures(fixtures_directory, fixture_set_names, class_names = {}, config = ActiveRecord::Base)
      fixture_set_names = Array(fixture_set_names).map(&:to_s)
      class_names = ClassCache.new class_names, config

      connection = block_given? ? yield : ActiveRecord::Base.connection

      files_to_read = fixture_set_names.reject { |fs_name|
        fixture_is_cached?(connection, fs_name)
      }

      unless files_to_read.empty?
        connection.disable_referential_integrity do
          fixtures_map = {}

          fixture_sets = files_to_read.map do |fs_name|
            klass = class_names[fs_name]
            conn = klass ? klass.connection : connection
            fixtures_map[fs_name] = new( # ActiveRecord::FixtureSet.new
              conn,
              fs_name,
              klass,
              ::File.join(fixtures_directory, fs_name))
          end

          update_all_loaded_fixtures fixtures_map

          connection.transaction(:requires_new => true) do
            fixture_sets.each do |fs|
              conn = fs.model_class.respond_to?(:connection) ? fs.model_class.connection : connection
              table_rows = fs.table_rows

              table_rows.each_key do |table|
                conn.delete "DELETE FROM #{conn.quote_table_name(table)}", 'Fixture Delete'
              end

              table_rows.each do |fixture_set_name, rows|
                rows.each do |row|
                  conn.insert_fixture(row, fixture_set_name)
                end
              end

              if conn.respond_to?(:reset_pk_sequence!)
                conn.reset_pk_sequence!(fs.table_name)
              end
            end
          end

          cache_fixtures(connection, fixtures_map)
        end
      end
      cached_fixtures(connection, fixture_set_names)
    end

    def self.identify(label, column_type = :integer)
      if column_type == :uuid
        Digest::UUID.uuid_v5(Digest::UUID::OID_NAMESPACE, label.to_s)
      else
        Zlib.crc32(label.to_s) % MAX_ID
      end
    end

    def self.context_class
      @context_class ||= Class.new
    end

    def self.update_all_loaded_fixtures(fixtures_map) # :nodoc:
      all_loaded_fixtures.update(fixtures_map)
    end

    attr_reader :table_name, :name, :fixtures, :model_class, :config

    def initialize(connection, name, class_name, path, config = ActiveRecord::Base)
      @name     = name
      @path     = path
      @config   = config
      @model_class = nil

      if class_name.is_a?(Class) # TODO: Should be an AR::Base type class, or any?
        @model_class = class_name
      else
        @model_class = class_name.safe_constantize if class_name
      end

      @connection  = connection

      @table_name = ( model_class.respond_to?(:table_name) ?
                      model_class.table_name :
                      self.class.default_fixture_table_name(name, config) )

      @fixtures = read_fixture_files path, @model_class
    end

    def [](x)
      fixtures[x]
    end

    def []=(k,v)
      fixtures[k] = v
    end

    def each(&block)
      fixtures.each(&block)
    end

    def size
      fixtures.size
    end

    def table_rows
      now = config.default_timezone == :utc ? Time.now.utc : Time.now
      now = now.to_s(:db)

      fixtures.delete('DEFAULTS')

      rows = Hash.new { |h,table| h[table] = [] }

      rows[table_name] = fixtures.map do |label, fixture|
        row = fixture.to_hash

        if model_class
          if model_class.record_timestamps
            timestamp_column_names.each do |c_name|
              row[c_name] = now unless row.key?(c_name)
            end
          end

          row.each do |key, value|
            row[key] = value.gsub("$LABEL", label.to_s) if value.is_a?(String)
          end

          if has_primary_key_column? && !row.include?(primary_key_name)
            row[primary_key_name] = ActiveRecord::FixtureSet.identify(label, primary_key_type)
          end

          reflection_class =
            if row.include?(inheritance_column_name)
              row[inheritance_column_name].constantize rescue model_class
            else
              model_class
            end

          reflection_class._reflections.each_value do |association|
            case association.macro
            when :belongs_to
              fk_name = (association.options[:foreign_key] || "#{association.name}_id").to_s

              if association.name.to_s != fk_name && value = row.delete(association.name.to_s)
                if association.polymorphic? && value.sub!(/\s*\(([^\)]*)\)\s*$/, "")
                  row[association.foreign_type] = $1
                end

                fk_type = reflection_class.columns_hash[fk_name].type
                row[fk_name] = ActiveRecord::FixtureSet.identify(value, fk_type)
              end
            when :has_many
              if association.options[:through]
                add_join_records(rows, row, HasManyThroughProxy.new(association))
              end
            end
          end
        end

        row
      end
      rows
    end

    class ReflectionProxy # :nodoc:
      def initialize(association)
        @association = association
      end

      def join_table
        @association.join_table
      end

      def name
        @association.name
      end

      def primary_key_type
        @association.klass.column_types[@association.klass.primary_key].type
      end
    end

    class HasManyThroughProxy < ReflectionProxy # :nodoc:
      def rhs_key
        @association.foreign_key
      end

      def lhs_key
        @association.through_reflection.foreign_key
      end

      def join_table
        @association.through_reflection.table_name
      end
    end

    private
      def primary_key_name
        @primary_key_name ||= model_class && model_class.primary_key
      end

      def primary_key_type
        @primary_key_type ||= model_class && model_class.column_types[model_class.primary_key].type
      end

      def add_join_records(rows, row, association)
        if (targets = row.delete(association.name.to_s))
          table_name  = association.join_table
          column_type = association.primary_key_type
          lhs_key     = association.lhs_key
          rhs_key     = association.rhs_key

          targets = targets.is_a?(Array) ? targets : targets.split(/\s*,\s*/)
          rows[table_name].concat targets.map { |target|
            { lhs_key => row[primary_key_name],
              rhs_key => ActiveRecord::FixtureSet.identify(target, column_type) }
          }
        end
      end

      def has_primary_key_column?
        @has_primary_key_column ||= primary_key_name &&
          model_class.columns.any? { |c| c.name == primary_key_name }
      end

      def timestamp_column_names
        @timestamp_column_names ||=
          %w(created_at created_on updated_at updated_on) & column_names
      end

      def inheritance_column_name
        @inheritance_column_name ||= model_class && model_class.inheritance_column
      end

      def column_names
        @column_names ||= @connection.columns(@table_name).collect { |c| c.name }
      end

      def read_fixture_files(path, model_class)
        yaml_files = Dir["#{path}/{**,*}/*.yml"].select { |f|
          ::File.file?(f)
        } + [yaml_file_path(path)]

        yaml_files.each_with_object({}) do |file, fixtures|
          FixtureSet::File.open(file) do |fh|
            fh.each do |fixture_name, row|
              fixtures[fixture_name] = ActiveRecord::Fixture.new(row, model_class)
            end
          end
        end
      end

      def yaml_file_path(path)
        "#{path}.yml"
      end

  end

  Fixtures = ActiveSupport::Deprecation::DeprecatedConstantProxy.new('ActiveRecord::Fixtures', 'ActiveRecord::FixtureSet')

  class Fixture #:nodoc:
    include Enumerable

    class FixtureError < StandardError #:nodoc:
    end

    class FormatError < FixtureError #:nodoc:
    end

    attr_reader :model_class, :fixture

    def initialize(fixture, model_class)
      @fixture     = fixture
      @model_class = model_class
    end

    def class_name
      model_class.name if model_class
    end

    def each
      fixture.each { |item| yield item }
    end

    def [](key)
      fixture[key]
    end

    alias :to_hash :fixture

    def find
      if model_class
        model_class.unscoped do
          model_class.find(fixture[model_class.primary_key])
        end
      else
        raise FixtureClassNotFound, "No class attached to find."
      end
    end
  end
end

module ActiveRecord
  module TestFixtures
    extend ActiveSupport::Concern

    def before_setup
      setup_fixtures
      super
    end

    def after_teardown
      super
      teardown_fixtures
    end

    included do
      class_attribute :fixture_path, :instance_writer => false
      class_attribute :fixture_table_names
      class_attribute :fixture_class_names
      class_attribute :use_transactional_fixtures
      class_attribute :use_instantiated_fixtures # true, false, or :no_instances
      class_attribute :pre_loaded_fixtures
      class_attribute :config

      self.fixture_table_names = []
      self.use_transactional_fixtures = true
      self.use_instantiated_fixtures = false
      self.pre_loaded_fixtures = false
      self.config = ActiveRecord::Base

      self.fixture_class_names = Hash.new do |h, fixture_set_name|
        h[fixture_set_name] = ActiveRecord::FixtureSet.default_fixture_model_name(fixture_set_name, self.config)
      end
    end

    module ClassMethods
      def set_fixture_class(class_names = {})
        self.fixture_class_names = self.fixture_class_names.merge(class_names.stringify_keys)
      end

      def fixtures(*fixture_set_names)
        if fixture_set_names.first == :all
          fixture_set_names = Dir["#{fixture_path}/{**,*}/*.{yml}"]
          fixture_set_names.map! { |f| f[(fixture_path.to_s.size + 1)..-5] }
        else
          fixture_set_names = fixture_set_names.flatten.map { |n| n.to_s }
        end

        self.fixture_table_names |= fixture_set_names
        setup_fixture_accessors(fixture_set_names)
      end

      def setup_fixture_accessors(fixture_set_names = nil)
        fixture_set_names = Array(fixture_set_names || fixture_table_names)
        methods = Module.new do
          fixture_set_names.each do |fs_name|
            fs_name = fs_name.to_s
            accessor_name = fs_name.tr('/', '_').to_sym

            #nodyna <define_method-794> <DM COMPLEX (events)>
            define_method(accessor_name) do |*fixture_names|
              force_reload = fixture_names.pop if fixture_names.last == true || fixture_names.last == :reload

              @fixture_cache[fs_name] ||= {}

              instances = fixture_names.map do |f_name|
                f_name = f_name.to_s
                @fixture_cache[fs_name].delete(f_name) if force_reload

                if @loaded_fixtures[fs_name][f_name]
                  @fixture_cache[fs_name][f_name] ||= @loaded_fixtures[fs_name][f_name].find
                else
                  raise StandardError, "No fixture named '#{f_name}' found for fixture set '#{fs_name}'"
                end
              end

              instances.size == 1 ? instances.first : instances
            end
            private accessor_name
          end
        end
        include methods
      end

      def uses_transaction(*methods)
        @uses_transaction = [] unless defined?(@uses_transaction)
        @uses_transaction.concat methods.map { |m| m.to_s }
      end

      def uses_transaction?(method)
        @uses_transaction = [] unless defined?(@uses_transaction)
        @uses_transaction.include?(method.to_s)
      end
    end

    def run_in_transaction?
      use_transactional_fixtures &&
        !self.class.uses_transaction?(method_name)
    end

    def setup_fixtures(config = ActiveRecord::Base)
      if pre_loaded_fixtures && !use_transactional_fixtures
        raise RuntimeError, 'pre_loaded_fixtures requires use_transactional_fixtures'
      end

      @fixture_cache = {}
      @fixture_connections = []
      @@already_loaded_fixtures ||= {}

      if run_in_transaction?
        if @@already_loaded_fixtures[self.class]
          @loaded_fixtures = @@already_loaded_fixtures[self.class]
        else
          @loaded_fixtures = load_fixtures(config)
          @@already_loaded_fixtures[self.class] = @loaded_fixtures
        end
        @fixture_connections = enlist_fixture_connections
        @fixture_connections.each do |connection|
          connection.begin_transaction joinable: false
        end
      else
        ActiveRecord::FixtureSet.reset_cache
        @@already_loaded_fixtures[self.class] = nil
        @loaded_fixtures = load_fixtures(config)
      end

      instantiate_fixtures if use_instantiated_fixtures
    end

    def teardown_fixtures
      if run_in_transaction?
        @fixture_connections.each do |connection|
          connection.rollback_transaction if connection.transaction_open?
        end
        @fixture_connections.clear
      else
        ActiveRecord::FixtureSet.reset_cache
      end

      ActiveRecord::Base.clear_active_connections!
    end

    def enlist_fixture_connections
      ActiveRecord::Base.connection_handler.connection_pool_list.map(&:connection)
    end

    private
      def load_fixtures(config)
        fixtures = ActiveRecord::FixtureSet.create_fixtures(fixture_path, fixture_table_names, fixture_class_names, config)
        Hash[fixtures.map { |f| [f.name, f] }]
      end

      def instantiate_fixtures
        if pre_loaded_fixtures
          raise RuntimeError, 'Load fixtures before instantiating them.' if ActiveRecord::FixtureSet.all_loaded_fixtures.empty?
          ActiveRecord::FixtureSet.instantiate_all_loaded_fixtures(self, load_instances?)
        else
          raise RuntimeError, 'Load fixtures before instantiating them.' if @loaded_fixtures.nil?
          @loaded_fixtures.each_value do |fixture_set|
            ActiveRecord::FixtureSet.instantiate_fixtures(self, fixture_set, load_instances?)
          end
        end
      end

      def load_instances?
        use_instantiated_fixtures != :no_instances
      end
  end
end

class ActiveRecord::FixtureSet::RenderContext # :nodoc:
  def self.create_subclass
    Class.new ActiveRecord::FixtureSet.context_class do
      def get_binding
        binding()
      end
    end
  end
end
