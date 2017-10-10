module ActiveRecord
  module CounterCache
    extend ActiveSupport::Concern

    module ClassMethods
      def reset_counters(id, *counters)
        object = find(id)
        counters.each do |counter_association|
          has_many_association = _reflect_on_association(counter_association)
          unless has_many_association
            has_many = reflect_on_all_associations(:has_many)
            has_many_association = has_many.find { |association| association.counter_cache_column && association.counter_cache_column.to_sym == counter_association.to_sym }
            counter_association = has_many_association.plural_name if has_many_association
          end
          raise ArgumentError, "'#{self.name}' has no association called '#{counter_association}'" unless has_many_association

          if has_many_association.is_a? ActiveRecord::Reflection::ThroughReflection
            has_many_association = has_many_association.through_reflection
          end

          foreign_key  = has_many_association.foreign_key.to_s
          child_class  = has_many_association.klass
          reflection   = child_class._reflections.values.find { |e| e.belongs_to? && e.foreign_key.to_s == foreign_key && e.options[:counter_cache].present? }
          counter_name = reflection.counter_cache_column

          stmt = unscoped.where(arel_table[primary_key].eq(object.id)).arel.compile_update({
            #nodyna <send-851> <SD COMPLEX (array)>
            arel_table[counter_name] => object.send(counter_association).count(:all)
          }, primary_key)
          connection.update stmt
        end
        return true
      end

      def update_counters(id, counters)
        updates = counters.map do |counter_name, value|
          operator = value < 0 ? '-' : '+'
          quoted_column = connection.quote_column_name(counter_name)
          "#{quoted_column} = COALESCE(#{quoted_column}, 0) #{operator} #{value.abs}"
        end

        unscoped.where(primary_key => id).update_all updates.join(', ')
      end

      def increment_counter(counter_name, id)
        update_counters(id, counter_name => 1)
      end

      def decrement_counter(counter_name, id)
        update_counters(id, counter_name => -1)
      end
    end

    protected

      def actually_destroyed?
        @_actually_destroyed
      end

      def clear_destroy_state
        @_actually_destroyed = nil
      end

    private

      def _create_record(*)
        id = super

        each_counter_cached_associations do |association|
          #nodyna <send-852> <SD COMPLEX (array)>
          if send(association.reflection.name)
            association.increment_counters
            @_after_create_counter_called = true
          end
        end

        id
      end

      def destroy_row
        affected_rows = super

        if affected_rows > 0
          each_counter_cached_associations do |association|
            foreign_key = association.reflection.foreign_key.to_sym
            unless destroyed_by_association && destroyed_by_association.foreign_key.to_sym == foreign_key
              #nodyna <send-853> <SD COMPLEX (array)>
              if send(association.reflection.name)
                association.decrement_counters
              end
            end
          end
        end

        affected_rows
      end

      def each_counter_cached_associations
        _reflections.each do |name, reflection|
          yield association(name.to_sym) if reflection.belongs_to? && reflection.counter_cache_column
        end
      end

  end
end
