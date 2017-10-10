require 'active_support/deprecation'
require 'active_support/core_ext/string/filters'

module ActiveRecord
  module FinderMethods
    ONE_AS_ONE = '1 AS one'

    def find(*args)
      if block_given?
        to_a.find(*args) { |*block_args| yield(*block_args) }
      else
        find_with_ids(*args)
      end
    end

    def find_by(*args)
      where(*args).take
    rescue RangeError
      nil
    end

    def find_by!(*args)
      where(*args).take!
    rescue RangeError
      raise RecordNotFound, "Couldn't find #{@klass.name} with an out of range value"
    end

    def take(limit = nil)
      limit ? limit(limit).to_a : find_take
    end

    def take!
      take or raise RecordNotFound.new("Couldn't find #{@klass.name} with [#{arel.where_sql}]")
    end

    def first(limit = nil)
      if limit
        find_nth_with_limit(offset_index, limit)
      else
        find_nth(0, offset_index)
      end
    end

    def first!
      find_nth! 0
    end

    def last(limit = nil)
      if limit
        if order_values.empty? && primary_key
          order(arel_table[primary_key].desc).limit(limit).reverse
        else
          to_a.last(limit)
        end
      else
        find_last
      end
    end

    def last!
      last or raise RecordNotFound.new("Couldn't find #{@klass.name} with [#{arel.where_sql}]")
    end

    def second
      find_nth(1, offset_index)
    end

    def second!
      find_nth! 1
    end

    def third
      find_nth(2, offset_index)
    end

    def third!
      find_nth! 2
    end

    def fourth
      find_nth(3, offset_index)
    end

    def fourth!
      find_nth! 3
    end

    def fifth
      find_nth(4, offset_index)
    end

    def fifth!
      find_nth! 4
    end

    def forty_two
      find_nth(41, offset_index)
    end

    def forty_two!
      find_nth! 41
    end

    def exists?(conditions = :none)
      if Base === conditions
        conditions = conditions.id
        ActiveSupport::Deprecation.warn(<<-MSG.squish)
          You are passing an instance of ActiveRecord::Base to `exists?`.
          Please pass the id of the object by calling `.id`
        MSG
      end

      return false if !conditions

      relation = apply_join_dependency(self, construct_join_dependency)
      return false if ActiveRecord::NullRelation === relation

      relation = relation.except(:select, :order).select(ONE_AS_ONE).limit(1)

      case conditions
      when Array, Hash
        relation = relation.where(conditions)
      else
        unless conditions == :none
          relation = relation.where(primary_key => conditions)
        end
      end

      connection.select_value(relation, "#{name} Exists", relation.arel.bind_values + relation.bind_values) ? true : false
    end

    def raise_record_not_found_exception!(ids, result_size, expected_size) #:nodoc:
      conditions = arel.where_sql
      conditions = " [#{conditions}]" if conditions

      if Array(ids).size == 1
        error = "Couldn't find #{@klass.name} with '#{primary_key}'=#{ids}#{conditions}"
      else
        error = "Couldn't find all #{@klass.name.pluralize} with '#{primary_key}': "
        error << "(#{ids.join(", ")})#{conditions} (found #{result_size} results, but was looking for #{expected_size})"
      end

      raise RecordNotFound, error
    end

    private

    def offset_index
      offset_value || 0
    end

    def find_with_associations
      join_dependency = construct_join_dependency(joins_values)

      aliases  = join_dependency.aliases
      relation = select aliases.columns
      relation = apply_join_dependency(relation, join_dependency)

      if block_given?
        yield relation
      else
        if ActiveRecord::NullRelation === relation
          []
        else
          arel = relation.arel
          rows = connection.select_all(arel, 'SQL', arel.bind_values + relation.bind_values)
          join_dependency.instantiate(rows, aliases)
        end
      end
    end

    def construct_join_dependency(joins = [])
      including = eager_load_values + includes_values
      ActiveRecord::Associations::JoinDependency.new(@klass, including, joins)
    end

    def construct_relation_for_association_calculations
      from = arel.froms.first
      if Arel::Table === from
        apply_join_dependency(self, construct_join_dependency(joins_values))
      else
        apply_join_dependency(self, construct_join_dependency(from))
      end
    end

    def apply_join_dependency(relation, join_dependency)
      relation = relation.except(:includes, :eager_load, :preload)
      relation = relation.joins join_dependency

      if using_limitable_reflections?(join_dependency.reflections)
        relation
      else
        if relation.limit_value
          limited_ids = limited_ids_for(relation)
          limited_ids.empty? ? relation.none! : relation.where!(table[primary_key].in(limited_ids))
        end
        relation.except(:limit, :offset)
      end
    end

    def limited_ids_for(relation)
      values = @klass.connection.columns_for_distinct(
        "#{quoted_table_name}.#{quoted_primary_key}", relation.order_values)

      relation = relation.except(:select).select(values).distinct!
      arel = relation.arel

      id_rows = @klass.connection.select_all(arel, 'SQL', arel.bind_values + relation.bind_values)
      id_rows.map {|row| row[primary_key]}
    end

    def using_limitable_reflections?(reflections)
      reflections.none? { |r| r.collection? }
    end

    protected

    def find_with_ids(*ids)
      raise UnknownPrimaryKey.new(@klass) if primary_key.nil?

      expects_array = ids.first.kind_of?(Array)
      return ids.first if expects_array && ids.first.empty?

      ids = ids.flatten.compact.uniq

      case ids.size
      when 0
        raise RecordNotFound, "Couldn't find #{@klass.name} without an ID"
      when 1
        result = find_one(ids.first)
        expects_array ? [ result ] : result
      else
        find_some(ids)
      end
    rescue RangeError
      raise RecordNotFound, "Couldn't find #{@klass.name} with an out of range ID"
    end

    def find_one(id)
      if ActiveRecord::Base === id
        id = id.id
        ActiveSupport::Deprecation.warn(<<-MSG.squish)
          You are passing an instance of ActiveRecord::Base to `find`.
          Please pass the id of the object by calling `.id`
        MSG
      end

      relation = where(primary_key => id)
      record = relation.take

      raise_record_not_found_exception!(id, 0, 1) unless record

      record
    end

    def find_some(ids)
      result = where(primary_key => ids).to_a

      expected_size =
        if limit_value && ids.size > limit_value
          limit_value
        else
          ids.size
        end

      if offset_value && (ids.size - offset_value < expected_size)
        expected_size = ids.size - offset_value
      end

      if result.size == expected_size
        result
      else
        raise_record_not_found_exception!(ids, result.size, expected_size)
      end
    end

    def find_take
      if loaded?
        @records.first
      else
        @take ||= limit(1).to_a.first
      end
    end

    def find_nth(index, offset)
      if loaded?
        @records[index]
      else
        offset += index
        @offsets[offset] ||= find_nth_with_limit(offset, 1).first
      end
    end

    def find_nth!(index)
      find_nth(index, offset_index) or raise RecordNotFound.new("Couldn't find #{@klass.name} with [#{arel.where_sql}]")
    end

    def find_nth_with_limit(offset, limit)
      relation = if order_values.empty? && primary_key
                   order(arel_table[primary_key].asc)
                 else
                   self
                 end

      relation = relation.offset(offset) unless offset.zero?
      relation.limit(limit).to_a
    end

    def find_last
      if loaded?
        @records.last
      else
        @last ||=
          if limit_value
            to_a.last
          else
            reverse_order.limit(1).to_a.first
          end
      end
    end
  end
end
