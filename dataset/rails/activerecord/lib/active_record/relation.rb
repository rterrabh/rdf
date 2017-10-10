require 'arel/collectors/bind'

module ActiveRecord
  class Relation
    MULTI_VALUE_METHODS  = [:includes, :eager_load, :preload, :select, :group,
                            :order, :joins, :where, :having, :bind, :references,
                            :extending, :unscope]

    SINGLE_VALUE_METHODS = [:limit, :offset, :lock, :readonly, :from, :reordering,
                            :reverse_order, :distinct, :create_with, :uniq]
    INVALID_METHODS_FOR_DELETE_ALL = [:limit, :distinct, :offset, :group, :having]

    VALUE_METHODS = MULTI_VALUE_METHODS + SINGLE_VALUE_METHODS

    include FinderMethods, Calculations, SpawnMethods, QueryMethods, Batches, Explain, Delegation

    attr_reader :table, :klass, :loaded
    alias :model :klass
    alias :loaded? :loaded

    def initialize(klass, table, values = {})
      @klass  = klass
      @table  = table
      @values = values
      @offsets = {}
      @loaded = false
    end

    def initialize_copy(other)
      @values        = Hash[@values]
      @values[:bind] = @values[:bind].dup if @values.key? :bind
      reset
    end

    def insert(values) # :nodoc:
      primary_key_value = nil

      if primary_key && Hash === values
        primary_key_value = values[values.keys.find { |k|
          k.name == primary_key
        }]

        if !primary_key_value && connection.prefetch_primary_key?(klass.table_name)
          primary_key_value = connection.next_sequence_value(klass.sequence_name)
          values[klass.arel_table[klass.primary_key]] = primary_key_value
        end
      end

      im = arel.create_insert
      im.into @table

      substitutes, binds = substitute_values values

      if values.empty? # empty insert
        im.values = Arel.sql(connection.empty_insert_statement_value)
      else
        im.insert substitutes
      end

      @klass.connection.insert(
        im,
        'SQL',
        primary_key,
        primary_key_value,
        nil,
        binds)
    end

    def _update_record(values, id, id_was) # :nodoc:
      substitutes, binds = substitute_values values

      scope = @klass.unscoped

      if @klass.finder_needs_type_condition?
        scope.unscope!(where: @klass.inheritance_column)
      end

      relation = scope.where(@klass.primary_key => (id_was || id))
      bvs = binds + relation.bind_values
      um = relation
        .arel
        .compile_update(substitutes, @klass.primary_key)

      @klass.connection.update(
        um,
        'SQL',
        bvs,
      )
    end

    def substitute_values(values) # :nodoc:
      binds = values.map do |arel_attr, value|
        [@klass.columns_hash[arel_attr.name], value]
      end

      substitutes = values.each_with_index.map do |(arel_attr, _), i|
        [arel_attr, @klass.connection.substitute_at(binds[i][0])]
      end

      [substitutes, binds]
    end

    def new(*args, &block)
      scoping { @klass.new(*args, &block) }
    end

    alias build new

    def create(*args, &block)
      scoping { @klass.create(*args, &block) }
    end

    def create!(*args, &block)
      scoping { @klass.create!(*args, &block) }
    end

    def first_or_create(attributes = nil, &block) # :nodoc:
      first || create(attributes, &block)
    end

    def first_or_create!(attributes = nil, &block) # :nodoc:
      first || create!(attributes, &block)
    end

    def first_or_initialize(attributes = nil, &block) # :nodoc:
      first || new(attributes, &block)
    end

    def find_or_create_by(attributes, &block)
      find_by(attributes) || create(attributes, &block)
    end

    def find_or_create_by!(attributes, &block)
      find_by(attributes) || create!(attributes, &block)
    end

    def find_or_initialize_by(attributes, &block)
      find_by(attributes) || new(attributes, &block)
    end

    def explain
      exec_explain(collecting_queries_for_explain { exec_queries })
    end

    def to_a
      load
      @records
    end

    def encode_with(coder)
      coder.represent_seq(nil, to_a)
    end

    def as_json(options = nil) #:nodoc:
      to_a.as_json(options)
    end

    def size
      loaded? ? @records.length : count(:all)
    end

    def empty?
      return @records.empty? if loaded?

      if limit_value == 0
        true
      else
        c = count(:all)
        c.respond_to?(:zero?) ? c.zero? : c.empty?
      end
    end

    def any?
      if block_given?
        to_a.any? { |*block_args| yield(*block_args) }
      else
        !empty?
      end
    end

    def many?
      if block_given?
        to_a.many? { |*block_args| yield(*block_args) }
      else
        limit_value ? to_a.many? : size > 1
      end
    end

    def scoping
      previous, klass.current_scope = klass.current_scope, self
      yield
    ensure
      klass.current_scope = previous
    end

    def update_all(updates)
      raise ArgumentError, "Empty list of attributes to change" if updates.blank?

      stmt = Arel::UpdateManager.new(arel.engine)

      #nodyna <send-753> <SD EASY (private methods)>
      stmt.set Arel.sql(@klass.send(:sanitize_sql_for_assignment, updates))
      stmt.table(table)
      stmt.key = table[primary_key]

      if joins_values.any?
        @klass.connection.join_to_update(stmt, arel)
      else
        stmt.take(arel.limit)
        stmt.order(*arel.orders)
        stmt.wheres = arel.constraints
      end

      bvs = arel.bind_values + bind_values
      @klass.connection.update stmt, 'SQL', bvs
    end

    def update(id, attributes)
      if id.is_a?(Array)
        id.map.with_index { |one_id, idx| update(one_id, attributes[idx]) }
      else
        object = find(id)
        object.update(attributes)
        object
      end
    end

    def destroy_all(conditions = nil)
      if conditions
        where(conditions).destroy_all
      else
        to_a.each {|object| object.destroy }.tap { reset }
      end
    end

    def destroy(id)
      if id.is_a?(Array)
        id.map { |one_id| destroy(one_id) }
      else
        find(id).destroy
      end
    end

    def delete_all(conditions = nil)
      invalid_methods = INVALID_METHODS_FOR_DELETE_ALL.select { |method|
        if MULTI_VALUE_METHODS.include?(method)
          #nodyna <send-754> <SD MODERATE (change-prone variables)>
          send("#{method}_values").any?
        else
          #nodyna <send-755> <SD MODERATE (change-prone variables)>
          send("#{method}_value")
        end
      }
      if invalid_methods.any?
        raise ActiveRecordError.new("delete_all doesn't support #{invalid_methods.join(', ')}")
      end

      if conditions
        where(conditions).delete_all
      else
        stmt = Arel::DeleteManager.new(arel.engine)
        stmt.from(table)

        if joins_values.any?
          @klass.connection.join_to_delete(stmt, arel, table[primary_key])
        else
          stmt.wheres = arel.constraints
        end

        bvs = arel.bind_values + bind_values
        affected = @klass.connection.delete(stmt, 'SQL', bvs)

        reset
        affected
      end
    end

    def delete(id_or_array)
      where(primary_key => id_or_array).delete_all
    end

    def load
      exec_queries unless loaded?

      self
    end

    def reload
      reset
      load
    end

    def reset
      @last = @to_sql = @order_clause = @scope_for_create = @arel = @loaded = nil
      @should_eager_load = @join_dependency = nil
      @records = []
      @offsets = {}
      self
    end

    def to_sql
      @to_sql ||= begin
                    relation   = self
                    connection = klass.connection
                    visitor    = connection.visitor

                    if eager_loading?
                      find_with_associations { |rel| relation = rel }
                    end

                    arel  = relation.arel
                    binds = (arel.bind_values + relation.bind_values).dup
                    binds.map! { |bv| connection.quote(*bv.reverse) }
                    collect = visitor.accept(arel.ast, Arel::Collectors::Bind.new)
                    collect.substitute_binds(binds).join
                  end
    end

    def where_values_hash(relation_table_name = table_name)
      equalities = where_values.grep(Arel::Nodes::Equality).find_all { |node|
        node.left.relation.name == relation_table_name
      }

      binds = Hash[bind_values.find_all(&:first).map { |column, v| [column.name, v] }]

      Hash[equalities.map { |where|
        name = where.left.name
        [name, binds.fetch(name.to_s) {
          case where.right
          when Array then where.right.map(&:val)
          when Arel::Nodes::Casted
            where.right.val
          end
        }]
      }]
    end

    def scope_for_create
      @scope_for_create ||= where_values_hash.merge(create_with_value)
    end

    def eager_loading?
      @should_eager_load ||=
        eager_load_values.any? ||
        includes_values.any? && (joined_includes_values.any? || references_eager_loaded_tables?)
    end

    def joined_includes_values
      includes_values & joins_values
    end

    def uniq_value
      distinct_value
    end

    def ==(other)
      case other
      when Associations::CollectionProxy, AssociationRelation
        self == other.to_a
      when Relation
        other.to_sql == to_sql
      when Array
        to_a == other
      end
    end

    def pretty_print(q)
      q.pp(self.to_a)
    end

    def blank?
      to_a.blank?
    end

    def values
      Hash[@values]
    end

    def inspect
      entries = to_a.take([limit_value, 11].compact.min).map!(&:inspect)
      entries[10] = '...' if entries.size == 11

      "#<#{self.class.name} [#{entries.join(', ')}]>"
    end

    private

    def exec_queries
      @records = eager_loading? ? find_with_associations : @klass.find_by_sql(arel, arel.bind_values + bind_values)

      preload = preload_values
      preload +=  includes_values unless eager_loading?
      preloader = build_preloader
      preload.each do |associations|
        preloader.preload @records, associations
      end

      @records.each { |record| record.readonly! } if readonly_value

      @loaded = true
      @records
    end

    def build_preloader
      ActiveRecord::Associations::Preloader.new
    end

    def references_eager_loaded_tables?
      joined_tables = arel.join_sources.map do |join|
        if join.is_a?(Arel::Nodes::StringJoin)
          tables_in_string(join.left)
        else
          [join.left.table_name, join.left.table_alias]
        end
      end

      joined_tables += [table.name, table.table_alias]

      joined_tables = joined_tables.flatten.compact.map { |t| t.downcase }.uniq

      (references_values - joined_tables).any?
    end

    def tables_in_string(string)
      return [] if string.blank?
      string.scan(/([a-zA-Z_][.\w]+).?\./).flatten.map{ |s| s.downcase }.uniq - ['raw_sql_']
    end
  end
end
