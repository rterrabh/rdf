module ActiveRecord
  module Locking
    module Optimistic
      extend ActiveSupport::Concern

      included do
        class_attribute :lock_optimistically, instance_writer: false
        self.lock_optimistically = true
      end

      def locking_enabled? #:nodoc:
        self.class.locking_enabled?
      end

      private
        def increment_lock
          lock_col = self.class.locking_column
          #nodyna <send-774> <SD MODERATE (change-prone variables)>
          previous_lock_value = send(lock_col).to_i
          #nodyna <send-775> <SD MODERATE (change-prone variables)>
          send(lock_col + '=', previous_lock_value + 1)
        end

        def _create_record(attribute_names = self.attribute_names, *) # :nodoc:
          if locking_enabled?
            attribute_names |= [self.class.locking_column]
          end
          super
        end

        def _update_record(attribute_names = self.attribute_names) #:nodoc:
          return super unless locking_enabled?
          return 0 if attribute_names.empty?

          lock_col = self.class.locking_column
          #nodyna <send-776> <SD MODERATE (change-prone variables)>
          previous_lock_value = send(lock_col).to_i
          increment_lock

          attribute_names += [lock_col]
          attribute_names.uniq!

          begin
            relation = self.class.unscoped

            affected_rows = relation.where(
              self.class.primary_key => id,
              lock_col => previous_lock_value,
            ).update_all(
              Hash[attributes_for_update(attribute_names).map do |name|
                [name, _read_attribute(name)]
              end]
            )

            unless affected_rows == 1
              raise ActiveRecord::StaleObjectError.new(self, "update")
            end

            affected_rows

          rescue Exception
            #nodyna <send-777> <SD MODERATE (change-prone variables)>
            send(lock_col + '=', previous_lock_value)
            raise
          end
        end

        def destroy_row
          affected_rows = super

          if locking_enabled? && affected_rows != 1
            raise ActiveRecord::StaleObjectError.new(self, "destroy")
          end

          affected_rows
        end

        def relation_for_destroy
          relation = super

          if locking_enabled?
            column_name = self.class.locking_column
            column      = self.class.columns_hash[column_name]
            substitute  = self.class.connection.substitute_at(column)

            relation = relation.where(self.class.arel_table[column_name].eq(substitute))
            relation.bind_values << [column, self[column_name].to_i]
          end

          relation
        end

      module ClassMethods
        DEFAULT_LOCKING_COLUMN = 'lock_version'

        def locking_enabled?
          lock_optimistically && columns_hash[locking_column]
        end

        def locking_column=(value)
          clear_caches_calculated_from_columns
          @locking_column = value.to_s
        end

        def locking_column
          reset_locking_column unless defined?(@locking_column)
          @locking_column
        end

        def reset_locking_column
          self.locking_column = DEFAULT_LOCKING_COLUMN
        end

        def update_counters(id, counters)
          counters = counters.merge(locking_column => 1) if locking_enabled?
          super
        end

        private

        def inherited(subclass)
          #nodyna <class_eval-778> <CE COMPLEX (block execution)>
          subclass.class_eval do
            is_lock_column = ->(name, _) { lock_optimistically && name == locking_column }
            decorate_matching_attribute_types(is_lock_column, :_optimistic_locking) do |type|
              LockingType.new(type)
            end
          end
          super
        end
      end
    end

    class LockingType < SimpleDelegator # :nodoc:
      def type_cast_from_database(value)
        super.to_i
      end

      def init_with(coder)
        __setobj__(coder['subtype'])
      end

      def encode_with(coder)
        coder['subtype'] = __getobj__
      end
    end
  end
end
