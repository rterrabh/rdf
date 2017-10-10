require 'active_support/core_ext/array/wrap'
require 'active_support/core_ext/string/filters'
require 'active_model/forbidden_attributes_protection'

module ActiveRecord
  module QueryMethods
    extend ActiveSupport::Concern

    include ActiveModel::ForbiddenAttributesProtection

    class WhereChain
      def initialize(scope)
        @scope = scope
      end

      def not(opts, *rest)
        #nodyna <send-812> <SD EASY (private methods)>
        where_value = @scope.send(:build_where, opts, rest).map do |rel|
          case rel
          when NilClass
            raise ArgumentError, 'Invalid argument for .where.not(), got nil.'
          when Arel::Nodes::In
            Arel::Nodes::NotIn.new(rel.left, rel.right)
          when Arel::Nodes::Equality
            Arel::Nodes::NotEqual.new(rel.left, rel.right)
          when String
            Arel::Nodes::Not.new(Arel::Nodes::SqlLiteral.new(rel))
          else
            Arel::Nodes::Not.new(rel)
          end
        end

        @scope.references!(PredicateBuilder.references(opts)) if Hash === opts
        @scope.where_values += where_value
        @scope
      end
    end

    Relation::MULTI_VALUE_METHODS.each do |name|
      #nodyna <class_eval-813> <not yet classified>
      class_eval <<-CODE, __FILE__, __LINE__ + 1
        def #{name}_values                   # def select_values
          @values[:#{name}] || []            #   @values[:select] || []
        end                                  # end
        def #{name}_values=(values)          # def select_values=(values)
          raise ImmutableRelation if @loaded #   raise ImmutableRelation if @loaded
          check_cached_relation
          @values[:#{name}] = values         #   @values[:select] = values
        end                                  # end
      CODE
    end

    (Relation::SINGLE_VALUE_METHODS - [:create_with]).each do |name|
      #nodyna <class_eval-814> <not yet classified>
      class_eval <<-CODE, __FILE__, __LINE__ + 1
        def #{name}_value                    # def readonly_value
          @values[:#{name}]                  #   @values[:readonly]
        end                                  # end
      CODE
    end

    Relation::SINGLE_VALUE_METHODS.each do |name|
      #nodyna <class_eval-815> <not yet classified>
      class_eval <<-CODE, __FILE__, __LINE__ + 1
        def #{name}_value=(value)            # def readonly_value=(value)
          raise ImmutableRelation if @loaded #   raise ImmutableRelation if @loaded
          check_cached_relation
          @values[:#{name}] = value          #   @values[:readonly] = value
        end                                  # end
      CODE
    end

    def check_cached_relation # :nodoc:
      if defined?(@arel) && @arel
        @arel = nil
        ActiveSupport::Deprecation.warn(<<-MSG.squish)
          Modifying already cached Relation. The cache will be reset. Use a
          cloned Relation to prevent this warning.
        MSG
      end
    end

    def create_with_value # :nodoc:
      @values[:create_with] || {}
    end

    alias extensions extending_values

    def includes(*args)
      check_if_method_has_arguments!(:includes, args)
      spawn.includes!(*args)
    end

    def includes!(*args) # :nodoc:
      args.reject!(&:blank?)
      args.flatten!

      self.includes_values |= args
      self
    end

    def eager_load(*args)
      check_if_method_has_arguments!(:eager_load, args)
      spawn.eager_load!(*args)
    end

    def eager_load!(*args) # :nodoc:
      self.eager_load_values += args
      self
    end

    def preload(*args)
      check_if_method_has_arguments!(:preload, args)
      spawn.preload!(*args)
    end

    def preload!(*args) # :nodoc:
      self.preload_values += args
      self
    end

    def references(*table_names)
      check_if_method_has_arguments!(:references, table_names)
      spawn.references!(*table_names)
    end

    def references!(*table_names) # :nodoc:
      table_names.flatten!
      table_names.map!(&:to_s)

      self.references_values |= table_names
      self
    end

    def select(*fields)
      if block_given?
        to_a.select { |*block_args| yield(*block_args) }
      else
        raise ArgumentError, 'Call this with at least one field' if fields.empty?
        spawn._select!(*fields)
      end
    end

    def _select!(*fields) # :nodoc:
      fields.flatten!
      fields.map! do |field|
        klass.attribute_alias?(field) ? klass.attribute_alias(field) : field
      end
      self.select_values += fields
      self
    end

    def group(*args)
      check_if_method_has_arguments!(:group, args)
      spawn.group!(*args)
    end

    def group!(*args) # :nodoc:
      args.flatten!

      self.group_values += args
      self
    end

    def order(*args)
      check_if_method_has_arguments!(:order, args)
      spawn.order!(*args)
    end

    def order!(*args) # :nodoc:
      preprocess_order_args(args)

      self.order_values += args
      self
    end

    def reorder(*args)
      check_if_method_has_arguments!(:reorder, args)
      spawn.reorder!(*args)
    end

    def reorder!(*args) # :nodoc:
      preprocess_order_args(args)

      self.reordering_value = true
      self.order_values = args
      self
    end

    VALID_UNSCOPING_VALUES = Set.new([:where, :select, :group, :order, :lock,
                                     :limit, :offset, :joins, :includes, :from,
                                     :readonly, :having])

    def unscope(*args)
      check_if_method_has_arguments!(:unscope, args)
      spawn.unscope!(*args)
    end

    def unscope!(*args) # :nodoc:
      args.flatten!
      self.unscope_values += args

      args.each do |scope|
        case scope
        when Symbol
          symbol_unscoping(scope)
        when Hash
          scope.each do |key, target_value|
            if key != :where
              raise ArgumentError, "Hash arguments in .unscope(*args) must have :where as the key."
            end

            Array(target_value).each do |val|
              where_unscoping(val)
            end
          end
        else
          raise ArgumentError, "Unrecognized scoping: #{args.inspect}. Use .unscope(where: :attribute_name) or .unscope(:order), for example."
        end
      end

      self
    end

    def joins(*args)
      check_if_method_has_arguments!(:joins, args)
      spawn.joins!(*args)
    end

    def joins!(*args) # :nodoc:
      args.compact!
      args.flatten!
      self.joins_values += args
      self
    end

    def bind(value) # :nodoc:
      spawn.bind!(value)
    end

    def bind!(value) # :nodoc:
      self.bind_values += [value]
      self
    end

    def where(opts = :chain, *rest)
      if opts == :chain
        WhereChain.new(spawn)
      elsif opts.blank?
        self
      else
        spawn.where!(opts, *rest)
      end
    end

    def where!(opts, *rest) # :nodoc:
      if Hash === opts
        opts = sanitize_forbidden_attributes(opts)
        references!(PredicateBuilder.references(opts))
      end

      self.where_values += build_where(opts, rest)
      self
    end

    def rewhere(conditions)
      unscope(where: conditions.keys).where(conditions)
    end

    def having(opts, *rest)
      opts.blank? ? self : spawn.having!(opts, *rest)
    end

    def having!(opts, *rest) # :nodoc:
      references!(PredicateBuilder.references(opts)) if Hash === opts

      self.having_values += build_where(opts, rest)
      self
    end

    def limit(value)
      spawn.limit!(value)
    end

    def limit!(value) # :nodoc:
      self.limit_value = value
      self
    end

    def offset(value)
      spawn.offset!(value)
    end

    def offset!(value) # :nodoc:
      self.offset_value = value
      self
    end

    def lock(locks = true)
      spawn.lock!(locks)
    end

    def lock!(locks = true) # :nodoc:
      case locks
      when String, TrueClass, NilClass
        self.lock_value = locks || true
      else
        self.lock_value = false
      end

      self
    end

    def none
      where("1=0").extending!(NullRelation)
    end

    def none! # :nodoc:
      where!("1=0").extending!(NullRelation)
    end

    def readonly(value = true)
      spawn.readonly!(value)
    end

    def readonly!(value = true) # :nodoc:
      self.readonly_value = value
      self
    end

    def create_with(value)
      spawn.create_with!(value)
    end

    def create_with!(value) # :nodoc:
      if value
        value = sanitize_forbidden_attributes(value)
        self.create_with_value = create_with_value.merge(value)
      else
        self.create_with_value = {}
      end

      self
    end

    def from(value, subquery_name = nil)
      spawn.from!(value, subquery_name)
    end

    def from!(value, subquery_name = nil) # :nodoc:
      self.from_value = [value, subquery_name]
      if value.is_a? Relation
        self.bind_values = value.arel.bind_values + value.bind_values + bind_values
      end
      self
    end

    def distinct(value = true)
      spawn.distinct!(value)
    end
    alias uniq distinct

    def distinct!(value = true) # :nodoc:
      self.distinct_value = value
      self
    end
    alias uniq! distinct!

    def extending(*modules, &block)
      if modules.any? || block
        spawn.extending!(*modules, &block)
      else
        self
      end
    end

    def extending!(*modules, &block) # :nodoc:
      modules << Module.new(&block) if block
      modules.flatten!

      self.extending_values += modules
      extend(*extending_values) if extending_values.any?

      self
    end

    def reverse_order
      spawn.reverse_order!
    end

    def reverse_order! # :nodoc:
      orders = order_values.uniq
      orders.reject!(&:blank?)
      self.order_values = reverse_sql_order(orders)
      self
    end

    def arel # :nodoc:
      @arel ||= build_arel
    end

    private

    def build_arel
      arel = Arel::SelectManager.new(table.engine, table)

      build_joins(arel, joins_values.flatten) unless joins_values.empty?

      collapse_wheres(arel, (where_values - [''])) #TODO: Add uniq with real value comparison / ignore uniqs that have binds

      arel.having(*having_values.uniq.reject(&:blank?)) unless having_values.empty?

      arel.take(connection.sanitize_limit(limit_value)) if limit_value
      arel.skip(offset_value.to_i) if offset_value
      arel.group(*arel_columns(group_values.uniq.reject(&:blank?))) unless group_values.empty?

      build_order(arel)

      build_select(arel)

      arel.distinct(distinct_value)
      arel.from(build_from) if from_value
      arel.lock(lock_value) if lock_value

      arel
    end

    def symbol_unscoping(scope)
      if !VALID_UNSCOPING_VALUES.include?(scope)
        raise ArgumentError, "Called unscope() with invalid unscoping argument ':#{scope}'. Valid arguments are :#{VALID_UNSCOPING_VALUES.to_a.join(", :")}."
      end

      single_val_method = Relation::SINGLE_VALUE_METHODS.include?(scope)
      unscope_code = "#{scope}_value#{'s' unless single_val_method}="

      case scope
      when :order
        result = []
      when :where
        self.bind_values = []
      else
        result = [] unless single_val_method
      end

      #nodyna <send-816> <SD COMPLEX (change-prone variables)>
      self.send(unscope_code, result)
    end

    def where_unscoping(target_value)
      target_value = target_value.to_s

      self.where_values = where_values.reject do |rel|
        case rel
        when Arel::Nodes::Between, Arel::Nodes::In, Arel::Nodes::NotIn, Arel::Nodes::Equality, Arel::Nodes::NotEqual, Arel::Nodes::LessThan, Arel::Nodes::LessThanOrEqual, Arel::Nodes::GreaterThan, Arel::Nodes::GreaterThanOrEqual
          subrelation = (rel.left.kind_of?(Arel::Attributes::Attribute) ? rel.left : rel.right)
          subrelation.name == target_value
        end
      end

      bind_values.reject! { |col,_| col.name == target_value }
    end

    def custom_join_ast(table, joins)
      joins = joins.reject(&:blank?)

      return [] if joins.empty?

      joins.map! do |join|
        case join
        when Array
          join = Arel.sql(join.join(' ')) if array_of_strings?(join)
        when String
          join = Arel.sql(join)
        end
        table.create_string_join(join)
      end
    end

    def collapse_wheres(arel, wheres)
      predicates = wheres.map do |where|
        next where if ::Arel::Nodes::Equality === where
        where = Arel.sql(where) if String === where
        Arel::Nodes::Grouping.new(where)
      end

      arel.where(Arel::Nodes::And.new(predicates)) if predicates.present?
    end

    def build_where(opts, other = [])
      case opts
      when String, Array
        #nodyna <send-817> <SD EASY (private methods)>
        [@klass.send(:sanitize_sql, other.empty? ? opts : ([opts] + other))]
      when Hash
        opts = PredicateBuilder.resolve_column_aliases(klass, opts)

        tmp_opts, bind_values = create_binds(opts)
        self.bind_values += bind_values

        #nodyna <send-818> <SD EASY (private methods)>
        attributes = @klass.send(:expand_hash_conditions_for_aggregates, tmp_opts)
        add_relations_to_bind_values(attributes)

        PredicateBuilder.build_from_hash(klass, attributes, table)
      else
        [opts]
      end
    end

    def create_binds(opts)
      bindable, non_binds = opts.partition do |column, value|
        PredicateBuilder.can_be_bound?(value) &&
          @klass.columns_hash.include?(column.to_s) &&
          !@klass.reflect_on_aggregation(column)
      end

      association_binds, non_binds = non_binds.partition do |column, value|
        value.is_a?(Hash) && association_for_table(column)
      end

      new_opts = {}
      binds = []

      connection = self.connection

      bindable.each do |(column,value)|
        binds.push [@klass.columns_hash[column.to_s], value]
        new_opts[column] = connection.substitute_at(column)
      end

      association_binds.each do |(column, value)|
        #nodyna <send-819> <SD EASY (private methods)>
        association_relation = association_for_table(column).klass.send(:relation)
        #nodyna <send-820> <SD EASY (private methods)>
        association_new_opts, association_bind = association_relation.send(:create_binds, value)
        new_opts[column] = association_new_opts
        binds += association_bind
      end

      non_binds.each { |column,value| new_opts[column] = value }

      [new_opts, binds]
    end

    def association_for_table(table_name)
      table_name = table_name.to_s
      @klass._reflect_on_association(table_name) ||
        @klass._reflect_on_association(table_name.singularize)
    end

    def build_from
      opts, name = from_value
      case opts
      when Relation
        name ||= 'subquery'
        opts.arel.as(name.to_s)
      else
        opts
      end
    end

    def build_joins(manager, joins)
      buckets = joins.group_by do |join|
        case join
        when String
          :string_join
        when Hash, Symbol, Array
          :association_join
        when ActiveRecord::Associations::JoinDependency
          :stashed_join
        when Arel::Nodes::Join
          :join_node
        else
          raise 'unknown class: %s' % join.class.name
        end
      end

      association_joins         = buckets[:association_join] || []
      stashed_association_joins = buckets[:stashed_join] || []
      join_nodes                = (buckets[:join_node] || []).uniq
      string_joins              = (buckets[:string_join] || []).map(&:strip).uniq

      join_list = join_nodes + custom_join_ast(manager, string_joins)

      join_dependency = ActiveRecord::Associations::JoinDependency.new(
        @klass,
        association_joins,
        join_list
      )

      join_infos = join_dependency.join_constraints stashed_association_joins

      join_infos.each do |info|
        info.joins.each { |join| manager.from(join) }
        manager.bind_values.concat info.binds
      end

      manager.join_sources.concat(join_list)

      manager
    end

    def build_select(arel)
      if select_values.any?
        arel.project(*arel_columns(select_values.uniq))
      else
        arel.project(@klass.arel_table[Arel.star])
      end
    end

    def arel_columns(columns)
      columns.map do |field|
        if (Symbol === field || String === field) && columns_hash.key?(field.to_s) && !from_value
          arel_table[field]
        elsif Symbol === field
          connection.quote_table_name(field.to_s)
        else
          field
        end
      end
    end

    def reverse_sql_order(order_query)
      order_query = ["#{quoted_table_name}.#{quoted_primary_key} ASC"] if order_query.empty?

      order_query.flat_map do |o|
        case o
        when Arel::Nodes::Ordering
          o.reverse
        when String
          o.to_s.split(',').map! do |s|
            s.strip!
            s.gsub!(/\sasc\Z/i, ' DESC') || s.gsub!(/\sdesc\Z/i, ' ASC') || s.concat(' DESC')
          end
        else
          o
        end
      end
    end

    def array_of_strings?(o)
      o.is_a?(Array) && o.all? { |obj| obj.is_a?(String) }
    end

    def build_order(arel)
      orders = order_values.uniq
      orders.reject!(&:blank?)

      arel.order(*orders) unless orders.empty?
    end

    VALID_DIRECTIONS = [:asc, :desc, :ASC, :DESC,
                        'asc', 'desc', 'ASC', 'DESC'] # :nodoc:

    def validate_order_args(args)
      args.each do |arg|
        next unless arg.is_a?(Hash)
        arg.each do |_key, value|
          raise ArgumentError, "Direction \"#{value}\" is invalid. Valid " \
                               "directions are: #{VALID_DIRECTIONS.inspect}" unless VALID_DIRECTIONS.include?(value)
        end
      end
    end

    def preprocess_order_args(order_args)
      order_args.flatten!
      validate_order_args(order_args)

      references = order_args.grep(String)
      references.map! { |arg| arg =~ /^([a-zA-Z]\w*)\.(\w+)/ && $1 }.compact!
      references!(references) if references.any?

      order_args.map! do |arg|
        case arg
        when Symbol
          arg = klass.attribute_alias(arg) if klass.attribute_alias?(arg)
          table[arg].asc
        when Hash
          arg.map { |field, dir|
            field = klass.attribute_alias(field) if klass.attribute_alias?(field)
            #nodyna <send-821> <SD COMPLEX (array)>
            table[field].send(dir.downcase)
          }
        else
          arg
        end
      end.flatten!
    end

    def check_if_method_has_arguments!(method_name, args)
      if args.blank?
        raise ArgumentError, "The method .#{method_name}() must contain arguments."
      end
    end

    def add_relations_to_bind_values(attributes)
      if attributes.is_a?(Hash)
        attributes.each_value do |value|
          if value.is_a?(ActiveRecord::Relation)
            self.bind_values += value.arel.bind_values + value.bind_values
          else
            add_relations_to_bind_values(value)
          end
        end
      end
    end
  end
end
