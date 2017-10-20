require 'active_support/core_ext/array/wrap'

module ActiveRecord
  module Associations
    class Association #:nodoc:
      attr_reader :owner, :target, :reflection
      attr_accessor :inversed

      delegate :options, :to => :reflection

      def initialize(owner, reflection)
        reflection.check_validity!

        @owner, @reflection = owner, reflection

        reset
        reset_scope
      end

      def aliased_table_name
        klass.table_name
      end

      def reset
        @loaded = false
        @target = nil
        @stale_state = nil
        @inversed = false
      end

      def reload
        reset
        reset_scope
        load_target
        self unless target.nil?
      end

      def loaded?
        @loaded
      end

      def loaded!
        @loaded = true
        @stale_state = stale_state
        @inversed = false
      end

      def stale_target?
        !inversed && loaded? && @stale_state != stale_state
      end

      def target=(target)
        @target = target
        loaded!
      end

      def scope
        target_scope.merge(association_scope)
      end

      def association_scope
        if klass
          @association_scope ||= AssociationScope.scope(self, klass.connection)
        end
      end

      def reset_scope
        @association_scope = nil
      end

      def set_inverse_instance(record)
        if invertible_for?(record)
          inverse = record.association(inverse_reflection_for(record).name)
          inverse.target = owner
          inverse.inversed = true
        end
        record
      end

      def klass
        reflection.klass
      end

      def target_scope
        AssociationRelation.create(klass, klass.arel_table, self).merge!(klass.all)
      end

      def load_target
        @target = find_target if (@stale_state && stale_target?) || find_target?

        loaded! unless loaded?
        target
      rescue ActiveRecord::RecordNotFound
        reset
      end

      def interpolate(sql, record = nil)
        if sql.respond_to?(:to_proc)
          #nodyna <instance_exec-905> <IEX COMPLEX (block with parameters)>
          owner.instance_exec(record, &sql)
        else
          sql
        end
      end

      def marshal_dump
        #nodyna <instance_variable_get-906> <IVG COMPLEX (array)>
        ivars = (instance_variables - [:@reflection]).map { |name| [name, instance_variable_get(name)] }
        [@reflection.name, ivars]
      end

      def marshal_load(data)
        reflection_name, ivars = data
        #nodyna <instance_variable_set-907> <IVS COMPLEX (array)>
        ivars.each { |name, val| instance_variable_set(name, val) }
        @reflection = @owner.class._reflect_on_association(reflection_name)
      end

      def initialize_attributes(record) #:nodoc:
        skip_assign = [reflection.foreign_key, reflection.type].compact
        attributes = create_scope.except(*(record.changed - skip_assign))
        record.assign_attributes(attributes)
        set_inverse_instance(record)
      end

      private

        def find_target?
          !loaded? && (!owner.new_record? || foreign_key_present?) && klass
        end

        def creation_attributes
          attributes = {}

          if (reflection.has_one? || reflection.collection?) && !options[:through]
            attributes[reflection.foreign_key] = owner[reflection.active_record_primary_key]

            if reflection.options[:as]
              attributes[reflection.type] = owner.class.base_class.name
            end
          end

          attributes
        end

        def set_owner_attributes(record)
          creation_attributes.each { |key, value| record[key] = value }
        end

        def foreign_key_present?
          false
        end

        def raise_on_type_mismatch!(record)
          unless record.is_a?(reflection.klass)
            fresh_class = reflection.class_name.safe_constantize
            unless fresh_class && record.is_a?(fresh_class)
              message = "#{reflection.class_name}(##{reflection.klass.object_id}) expected, got #{record.class}(##{record.class.object_id})"
              raise ActiveRecord::AssociationTypeMismatch, message
            end
          end
        end

        def inverse_reflection_for(record)
          reflection.inverse_of
        end

        def invertible_for?(record)
          foreign_key_for?(record) && inverse_reflection_for(record)
        end

        def foreign_key_for?(record)
          record.has_attribute?(reflection.foreign_key)
        end

        def stale_state
        end

        def build_record(attributes)
          reflection.build_association(attributes) do |record|
            initialize_attributes(record)
          end
        end

        def skip_statement_cache?
          reflection.scope_chain.any?(&:any?) ||
            scope.eager_loading? ||
            klass.current_scope ||
            klass.default_scopes.any? ||
            reflection.source_reflection.active_record.default_scopes.any?
        end
    end
  end
end
