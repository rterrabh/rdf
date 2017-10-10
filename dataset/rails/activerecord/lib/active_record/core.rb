require 'thread'
require 'active_support/core_ext/hash/indifferent_access'
require 'active_support/core_ext/object/duplicable'
require 'active_support/core_ext/string/filters'

module ActiveRecord
  module Core
    extend ActiveSupport::Concern

    included do
      mattr_accessor :logger, instance_writer: false

      def self.configurations=(config)
        @@configurations = ActiveRecord::ConnectionHandling::MergeAndResolveDefaultUrlConfig.new(config).resolve
      end
      self.configurations = {}

      def self.configurations
        @@configurations
      end

      mattr_accessor :default_timezone, instance_writer: false
      self.default_timezone = :utc

      mattr_accessor :schema_format, instance_writer: false
      self.schema_format = :ruby

      mattr_accessor :timestamped_migrations, instance_writer: false
      self.timestamped_migrations = true

      mattr_accessor :dump_schema_after_migration, instance_writer: false
      self.dump_schema_after_migration = true

      mattr_accessor :maintain_test_schema, instance_accessor: false

      def self.disable_implicit_join_references=(value)
        ActiveSupport::Deprecation.warn(<<-MSG.squish)
          Implicit join references were removed with Rails 4.1.
          Make sure to remove this configuration because it does nothing.
        MSG
      end

      class_attribute :default_connection_handler, instance_writer: false
      class_attribute :find_by_statement_cache

      def self.connection_handler
        ActiveRecord::RuntimeRegistry.connection_handler || default_connection_handler
      end

      def self.connection_handler=(handler)
        ActiveRecord::RuntimeRegistry.connection_handler = handler
      end

      self.default_connection_handler = ConnectionAdapters::ConnectionHandler.new
    end

    module ClassMethods
      def allocate
        define_attribute_methods
        super
      end

      def initialize_find_by_cache # :nodoc:
        self.find_by_statement_cache = {}.extend(Mutex_m)
      end

      def inherited(child_class) # :nodoc:
        child_class.initialize_find_by_cache
        super
      end

      def find(*ids) # :nodoc:
        return super unless ids.length == 1
        return super if ids.first.kind_of?(Symbol)
        return super if block_given? ||
                        primary_key.nil? ||
                        default_scopes.any? ||
                        current_scope ||
                        columns_hash.include?(inheritance_column) ||
                        ids.first.kind_of?(Array)

        id  = ids.first
        if ActiveRecord::Base === id
          id = id.id
          ActiveSupport::Deprecation.warn(<<-MSG.squish)
            You are passing an instance of ActiveRecord::Base to `find`.
            Please pass the id of the object by calling `.id`
          MSG
        end
        key = primary_key

        s = find_by_statement_cache[key] || find_by_statement_cache.synchronize {
          find_by_statement_cache[key] ||= StatementCache.create(connection) { |params|
            where(key => params.bind).limit(1)
          }
        }
        record = s.execute([id], self, connection).first
        unless record
          raise RecordNotFound, "Couldn't find #{name} with '#{primary_key}'=#{id}"
        end
        record
      rescue RangeError
        raise RecordNotFound, "Couldn't find #{name} with an out of range value for '#{primary_key}'"
      end

      def find_by(*args) # :nodoc:
        return super if current_scope || !(Hash === args.first) || reflect_on_all_aggregations.any?
        return super if default_scopes.any?

        hash = args.first

        return super if hash.values.any? { |v|
          v.nil? || Array === v || Hash === v
        }

        return super unless hash.keys.all? { |k| columns_hash.has_key?(k.to_s) }

        key  = hash.keys

        klass = self
        s = find_by_statement_cache[key] || find_by_statement_cache.synchronize {
          find_by_statement_cache[key] ||= StatementCache.create(connection) { |params|
            wheres = key.each_with_object({}) { |param,o|
              o[param] = params.bind
            }
            klass.where(wheres).limit(1)
          }
        }
        begin
          s.execute(hash.values, self, connection).first
        rescue TypeError => e
          raise ActiveRecord::StatementInvalid.new(e.message, e)
        rescue RangeError
          nil
        end
      end

      def find_by!(*args) # :nodoc:
        find_by(*args) or raise RecordNotFound.new("Couldn't find #{name}")
      end

      def initialize_generated_modules # :nodoc:
        generated_association_methods
      end

      def generated_association_methods
        @generated_association_methods ||= begin
          #nodyna <const_set-857> <CS TRIVIAL (static values)>
          mod = const_set(:GeneratedAssociationMethods, Module.new)
          include mod
          mod
        end
      end

      def inspect
        if self == Base
          super
        elsif abstract_class?
          "#{super}(abstract)"
        elsif !connected?
          "#{super} (call '#{super}.connection' to establish a connection)"
        elsif table_exists?
          attr_list = columns.map { |c| "#{c.name}: #{c.type}" } * ', '
          "#{super}(#{attr_list})"
        else
          "#{super}(Table doesn't exist)"
        end
      end

      def ===(object)
        object.is_a?(self)
      end

      def arel_table # :nodoc:
        @arel_table ||= Arel::Table.new(table_name, arel_engine)
      end

      def arel_engine # :nodoc:
        @arel_engine ||=
          if Base == self || connection_handler.retrieve_connection_pool(self)
            self
          else
            superclass.arel_engine
          end
      end

      private

      def relation #:nodoc:
        relation = Relation.create(self, arel_table)

        if finder_needs_type_condition?
          relation.where(type_condition).create_with(inheritance_column.to_sym => sti_name)
        else
          relation
        end
      end
    end

    def initialize(attributes = nil, options = {})
      @attributes = self.class._default_attributes.dup
      self.class.define_attribute_methods

      init_internals
      initialize_internals_callback

      init_attributes(attributes, options) if attributes

      yield self if block_given?
      _run_initialize_callbacks
    end

    def init_with(coder)
      @attributes = coder['attributes']

      init_internals

      @new_record = coder['new_record']

      self.class.define_attribute_methods

      _run_find_callbacks
      _run_initialize_callbacks

      self
    end



    def initialize_dup(other) # :nodoc:
      @attributes = @attributes.dup
      @attributes.reset(self.class.primary_key)

      _run_initialize_callbacks

      @aggregation_cache = {}
      @association_cache = {}

      @new_record  = true
      @destroyed   = false

      super
    end

    def encode_with(coder)
      coder['raw_attributes'] = attributes_before_type_cast
      coder['attributes'] = @attributes
      coder['new_record'] = new_record?
    end

    def ==(comparison_object)
      super ||
        comparison_object.instance_of?(self.class) &&
        !id.nil? &&
        comparison_object.id == id
    end
    alias :eql? :==

    def hash
      if id
        id.hash
      else
        super
      end
    end

    def freeze
      @attributes = @attributes.clone.freeze
      self
    end

    def frozen?
      @attributes.frozen?
    end

    def <=>(other_object)
      if other_object.is_a?(self.class)
        self.to_key <=> other_object.to_key
      else
        super
      end
    end

    def readonly?
      @readonly
    end

    def readonly!
      @readonly = true
    end

    def connection_handler
      self.class.connection_handler
    end

    def inspect
      inspection = if defined?(@attributes) && @attributes
                     self.class.column_names.collect { |name|
                       if has_attribute?(name)
                         "#{name}: #{attribute_for_inspect(name)}"
                       end
                     }.compact.join(", ")
                   else
                     "not initialized"
                   end
      "#<#{self.class} #{inspection}>"
    end

    def pretty_print(pp)
      return super if custom_inspect_method_defined?
      pp.object_address_group(self) do
        if defined?(@attributes) && @attributes
          column_names = self.class.column_names.select { |name| has_attribute?(name) || new_record? }
          pp.seplist(column_names, proc { pp.text ',' }) do |column_name|
            column_value = read_attribute(column_name)
            pp.breakable ' '
            pp.group(1) do
              pp.text column_name
              pp.text ':'
              pp.breakable
              pp.pp column_value
            end
          end
        else
          pp.breakable ' '
          pp.text 'not initialized'
        end
      end
    end

    def slice(*methods)
      #nodyna <send-858> <SD MODERATE (array)>
      Hash[methods.map! { |method| [method, public_send(method)] }].with_indifferent_access
    end

    private

    def set_transaction_state(state) # :nodoc:
      @transaction_state = state
    end

    def has_transactional_callbacks? # :nodoc:
      !_rollback_callbacks.empty? || !_commit_callbacks.empty?
    end

    def sync_with_transaction_state
      update_attributes_from_transaction_state(@transaction_state, 0)
    end

    def update_attributes_from_transaction_state(transaction_state, depth)
      @reflects_state = [false] if depth == 0

      if transaction_state && transaction_state.finalized? && !has_transactional_callbacks?
        unless @reflects_state[depth]
          restore_transaction_record_state if transaction_state.rolledback?
          clear_transaction_record_state
          @reflects_state[depth] = true
        end

        if transaction_state.parent && !@reflects_state[depth+1]
          update_attributes_from_transaction_state(transaction_state.parent, depth+1)
        end
      end
    end

    def to_ary # :nodoc:
      nil
    end

    def init_internals
      @aggregation_cache        = {}
      @association_cache        = {}
      @readonly                 = false
      @destroyed                = false
      @marked_for_destruction   = false
      @destroyed_by_association = nil
      @new_record               = true
      @txn                      = nil
      @_start_transaction_state = {}
      @transaction_state        = nil
    end

    def initialize_internals_callback
    end

    def init_attributes(attributes, options)
      assign_attributes(attributes)
    end

    def thaw
      if frozen?
        @attributes = @attributes.dup
      end
    end

    def custom_inspect_method_defined?
      self.class.instance_method(:inspect).owner != ActiveRecord::Base.instance_method(:inspect).owner
    end
  end
end
