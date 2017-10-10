module ActiveRecord
  module Associations
    module ThroughAssociation #:nodoc:

      delegate :source_reflection, :through_reflection, :to => :reflection

      protected

        def target_scope
          scope = super
          reflection.chain.drop(1).each do |reflection|
            relation = reflection.klass.all
            scope.merge!(
              relation.except(:select, :create_with, :includes, :preload, :joins, :eager_load)
            )
          end
          scope
        end

      private

        def construct_join_attributes(*records)
          ensure_mutable

          if source_reflection.association_primary_key(reflection.klass) == reflection.klass.primary_key
            join_attributes = { source_reflection.name => records }
          else
            join_attributes = {
              source_reflection.foreign_key =>
                records.map { |record|
                  #nodyna <send-898> <SD COMPLEX (change-prone variables)>
                  record.send(source_reflection.association_primary_key(reflection.klass))
                }
            }
          end

          if options[:source_type]
            join_attributes[source_reflection.foreign_type] =
              records.map { |record| record.class.base_class.name }
          end

          if records.count == 1
            Hash[join_attributes.map { |k, v| [k, v.first] }]
          else
            join_attributes
          end
        end

        def stale_state
          if through_reflection.belongs_to?
            owner[through_reflection.foreign_key] && owner[through_reflection.foreign_key].to_s
          end
        end

        def foreign_key_present?
          through_reflection.belongs_to? && !owner[through_reflection.foreign_key].nil?
        end

        def ensure_mutable
          unless source_reflection.belongs_to?
            raise HasManyThroughCantAssociateThroughHasOneOrManyReflection.new(owner, reflection)
          end
        end

        def ensure_not_nested
          if reflection.nested?
            raise HasManyThroughNestedAssociationsAreReadonly.new(owner, reflection)
          end
        end

        def build_record(attributes)
          inverse = source_reflection.inverse_of
          target = through_association.target

          if inverse && target && !target.is_a?(Array)
            attributes[inverse.foreign_key] = target.id
          end

          super(attributes)
        end
    end
  end
end
