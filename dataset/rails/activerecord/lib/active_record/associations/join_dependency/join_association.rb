require 'active_record/associations/join_dependency/join_part'

module ActiveRecord
  module Associations
    class JoinDependency # :nodoc:
      class JoinAssociation < JoinPart # :nodoc:
        attr_reader :reflection

        attr_accessor :tables

        def initialize(reflection, children)
          super(reflection.klass, children)

          @reflection      = reflection
          @tables          = nil
        end

        def match?(other)
          return true if self == other
          super && reflection == other.reflection
        end

        JoinInformation = Struct.new :joins, :binds

        def join_constraints(foreign_table, foreign_klass, node, join_type, tables, scope_chain, chain)
          joins         = []
          bind_values   = []
          tables        = tables.reverse

          scope_chain_index = 0
          scope_chain = scope_chain.reverse

          chain.reverse_each do |reflection|
            table = tables.shift
            klass = reflection.klass

            join_keys   = reflection.join_keys(klass)
            key         = join_keys.key
            foreign_key = join_keys.foreign_key

            constraint = build_constraint(klass, table, key, foreign_table, foreign_key)

            scope_chain_items = scope_chain[scope_chain_index].map do |item|
              if item.is_a?(Relation)
                item
              else
                #nodyna <instance_exec-877> <IEX COMPLEX (block with parameters)>
                ActiveRecord::Relation.create(klass, table).instance_exec(node, &item)
              end
            end
            scope_chain_index += 1

            #nodyna <send-878> <SD EASY (private methods)>
            scope_chain_items.concat [klass.send(:build_default_scope, ActiveRecord::Relation.create(klass, table))].compact

            rel = scope_chain_items.inject(scope_chain_items.shift) do |left, right|
              left.merge right
            end

            if rel && !rel.arel.constraints.empty?
              bind_values.concat rel.bind_values
              constraint = constraint.and rel.arel.constraints
            end

            if reflection.type
              value = foreign_klass.base_class.name
              column = klass.columns_hash[reflection.type.to_s]

              substitute = klass.connection.substitute_at(column)
              bind_values.push [column, value]
              constraint = constraint.and table[reflection.type].eq substitute
            end

            joins << table.create_join(table, table.create_on(constraint), join_type)

            foreign_table, foreign_klass = table, klass
          end

          JoinInformation.new joins, bind_values
        end

        def build_constraint(klass, table, key, foreign_table, foreign_key)
          constraint = table[key].eq(foreign_table[foreign_key])

          if klass.finder_needs_type_condition?
            constraint = table.create_and([
              constraint,
              #nodyna <send-879> <SD EASY (private methods)>
              klass.send(:type_condition, table)
            ])
          end

          constraint
        end

        def table
          tables.first
        end

        def aliased_table_name
          table.table_alias || table.name
        end
      end
    end
  end
end
