module ActiveRecord
  module Associations
    class CollectionAssociation < Association #:nodoc:

      def reader(force_reload = false)
        if force_reload
          klass.uncached { reload }
        elsif stale_target?
          reload
        end

        if owner.new_record?
          @new_record_proxy ||= CollectionProxy.create(klass, self)
        else
          @proxy ||= CollectionProxy.create(klass, self)
        end
      end

      def writer(records)
        replace(records)
      end

      def ids_reader
        if loaded?
          load_target.map do |record|
            #nodyna <send-872> <SD COMPLEX (change-prone variables)>
            record.send(reflection.association_primary_key)
          end
        else
          column  = "#{reflection.quoted_table_name}.#{reflection.association_primary_key}"
          scope.pluck(column)
        end
      end

      def ids_writer(ids)
        pk_type = reflection.primary_key_type
        ids = Array(ids).reject { |id| id.blank? }
        ids.map! { |i| pk_type.type_cast_from_user(i) }
        replace(klass.find(ids).index_by { |r| r.id }.values_at(*ids))
      end

      def reset
        super
        @target = []
      end

      def select(*fields)
        if block_given?
          load_target.select.each { |e| yield e }
        else
          scope.select(*fields)
        end
      end

      def find(*args)
        if block_given?
          load_target.find(*args) { |*block_args| yield(*block_args) }
        else
          if options[:inverse_of] && loaded?
            args_flatten = args.flatten
            raise RecordNotFound, "Couldn't find #{scope.klass.name} without an ID" if args_flatten.blank?
            result = find_by_scan(*args)

            result_size = Array(result).size
            if !result || result_size != args_flatten.size
              scope.raise_record_not_found_exception!(args_flatten, result_size, args_flatten.size)
            else
              result
            end
          else
            scope.find(*args)
          end
        end
      end

      def first(*args)
        first_nth_or_last(:first, *args)
      end

      def second(*args)
        first_nth_or_last(:second, *args)
      end

      def third(*args)
        first_nth_or_last(:third, *args)
      end

      def fourth(*args)
        first_nth_or_last(:fourth, *args)
      end

      def fifth(*args)
        first_nth_or_last(:fifth, *args)
      end

      def forty_two(*args)
        first_nth_or_last(:forty_two, *args)
      end

      def last(*args)
        first_nth_or_last(:last, *args)
      end

      def take(n = nil)
        if loaded?
          n ? target.take(n) : target.first
        else
          scope.take(n).tap do |record|
            set_inverse_instance record if record.is_a? ActiveRecord::Base
          end
        end
      end

      def build(attributes = {}, &block)
        if attributes.is_a?(Array)
          attributes.collect { |attr| build(attr, &block) }
        else
          add_to_target(build_record(attributes)) do |record|
            yield(record) if block_given?
          end
        end
      end

      def create(attributes = {}, &block)
        _create_record(attributes, &block)
      end

      def create!(attributes = {}, &block)
        _create_record(attributes, true, &block)
      end

      def concat(*records)
        if owner.new_record?
          load_target
          concat_records(records)
        else
          transaction { concat_records(records) }
        end
      end

      def transaction(*args)
        reflection.klass.transaction(*args) do
          yield
        end
      end

      def delete_all(dependent = nil)
        if dependent && ![:nullify, :delete_all].include?(dependent)
          raise ArgumentError, "Valid values are :nullify or :delete_all"
        end

        dependent = if dependent
                      dependent
                    elsif options[:dependent] == :destroy
                      :delete_all
                    else
                      options[:dependent]
                    end

        delete_or_nullify_all_records(dependent).tap do
          reset
          loaded!
        end
      end

      def destroy_all
        destroy(load_target).tap do
          reset
          loaded!
        end
      end

      def count(column_name = nil, count_options = {})
        column_name, count_options = nil, column_name if column_name.is_a?(Hash)

        relation = scope
        if association_scope.distinct_value
          column_name ||= reflection.klass.primary_key
          relation = relation.distinct
        end

        value = relation.count(column_name)

        limit  = options[:limit]
        offset = options[:offset]

        if limit || offset
          [ [value - offset.to_i, 0].max, limit.to_i ].min
        else
          value
        end
      end

      def delete(*records)
        return if records.empty?
        _options = records.extract_options!
        dependent = _options[:dependent] || options[:dependent]

        records = find(records) if records.any? { |record| record.kind_of?(Fixnum) || record.kind_of?(String) }
        delete_or_destroy(records, dependent)
      end

      def destroy(*records)
        return if records.empty?
        records = find(records) if records.any? { |record| record.kind_of?(Fixnum) || record.kind_of?(String) }
        delete_or_destroy(records, :destroy)
      end

      def size
        if !find_target? || loaded?
          if association_scope.distinct_value
            target.uniq.size
          else
            target.size
          end
        elsif !loaded? && !association_scope.group_values.empty?
          load_target.size
        elsif !loaded? && !association_scope.distinct_value && target.is_a?(Array)
          unsaved_records = target.select { |r| r.new_record? }
          unsaved_records.size + count_records
        else
          count_records
        end
      end

      def length
        load_target.size
      end

      def empty?
        if loaded?
          size.zero?
        else
          @target.blank? && !scope.exists?
        end
      end

      def any?
        if block_given?
          load_target.any? { |*block_args| yield(*block_args) }
        else
          !empty?
        end
      end

      def many?
        if block_given?
          load_target.many? { |*block_args| yield(*block_args) }
        else
          size > 1
        end
      end

      def distinct
        seen = {}
        load_target.find_all do |record|
          seen[record.id] = true unless seen.key?(record.id)
        end
      end
      alias uniq distinct

      def replace(other_array)
        other_array.each { |val| raise_on_type_mismatch!(val) }
        original_target = load_target.dup

        if owner.new_record?
          replace_records(other_array, original_target)
        else
          replace_common_records_in_memory(other_array, original_target)
          if other_array != original_target
            transaction { replace_records(other_array, original_target) }
          end
        end
      end

      def include?(record)
        if record.is_a?(reflection.klass)
          if record.new_record?
            include_in_memory?(record)
          else
            loaded? ? target.include?(record) : scope.exists?(record.id)
          end
        else
          false
        end
      end

      def load_target
        if find_target?
          @target = merge_target_lists(find_target, target)
        end

        loaded!
        target
      end

      def add_to_target(record, skip_callbacks = false, &block)
        if association_scope.distinct_value
          index = @target.index(record)
        end
        replace_on_target(record, index, skip_callbacks, &block)
      end

      def replace_on_target(record, index, skip_callbacks)
        callback(:before_add, record) unless skip_callbacks
        yield(record) if block_given?

        if index
          @target[index] = record
        else
          @target << record
        end

        callback(:after_add, record) unless skip_callbacks
        set_inverse_instance(record)

        record
      end

      def scope(opts = {})
        scope = super()
        scope.none! if opts.fetch(:nullify, true) && null_scope?
        scope
      end

      def null_scope?
        owner.new_record? && !foreign_key_present?
      end

      private
      def get_records
        return scope.to_a if skip_statement_cache?

        conn = klass.connection
        sc = reflection.association_scope_cache(conn, owner) do
          StatementCache.create(conn) { |params|
            as = AssociationScope.create { params.bind }
            target_scope.merge as.scope(self, conn)
          }
        end

        binds = AssociationScope.get_bind_values(owner, reflection.chain)
        sc.execute binds, klass, klass.connection
      end

        def find_target
          records = get_records
          records.each { |record| set_inverse_instance(record) }
          records
        end

        def merge_target_lists(persisted, memory)
          return persisted if memory.empty?
          return memory    if persisted.empty?

          persisted.map! do |record|
            if mem_record = memory.delete(record)

              ((record.attribute_names & mem_record.attribute_names) - mem_record.changes.keys).each do |name|
                mem_record[name] = record[name]
              end

              mem_record
            else
              record
            end
          end

          persisted + memory
        end

        def _create_record(attributes, raise = false, &block)
          unless owner.persisted?
            raise ActiveRecord::RecordNotSaved, "You cannot call create unless the parent is saved"
          end

          if attributes.is_a?(Array)
            attributes.collect { |attr| _create_record(attr, raise, &block) }
          else
            transaction do
              add_to_target(build_record(attributes)) do |record|
                yield(record) if block_given?
                insert_record(record, true, raise)
              end
            end
          end
        end

        def insert_record(record, validate = true, raise = false)
          raise NotImplementedError
        end

        def create_scope
          scope.scope_for_create.stringify_keys
        end

        def delete_or_destroy(records, method)
          records = records.flatten
          records.each { |record| raise_on_type_mismatch!(record) }
          existing_records = records.reject { |r| r.new_record? }

          if existing_records.empty?
            remove_records(existing_records, records, method)
          else
            transaction { remove_records(existing_records, records, method) }
          end
        end

        def remove_records(existing_records, records, method)
          records.each { |record| callback(:before_remove, record) }

          delete_records(existing_records, method) if existing_records.any?
          records.each { |record| target.delete(record) }

          records.each { |record| callback(:after_remove, record) }
        end

        def delete_records(records, method)
          raise NotImplementedError
        end

        def replace_records(new_target, original_target)
          delete(target - new_target)

          unless concat(new_target - target)
            @target = original_target
            raise RecordNotSaved, "Failed to replace #{reflection.name} because one or more of the " \
                                  "new records could not be saved."
          end

          target
        end

        def replace_common_records_in_memory(new_target, original_target)
          common_records = new_target & original_target
          common_records.each do |record|
            skip_callbacks = true
            replace_on_target(record, @target.index(record), skip_callbacks)
          end
        end

        def concat_records(records, should_raise = false)
          result = true

          records.flatten.each do |record|
            raise_on_type_mismatch!(record)
            add_to_target(record) do |rec|
              result &&= insert_record(rec, true, should_raise) unless owner.new_record?
            end
          end

          result && records
        end

        def callback(method, record)
          callbacks_for(method).each do |callback|
            callback.call(method, owner, record)
          end
        end

        def callbacks_for(callback_name)
          full_callback_name = "#{callback_name}_for_#{reflection.name}"
          #nodyna <send-873> <SD COMPLEX (change-prone variables)>
          owner.class.send(full_callback_name)
        end

        def fetch_first_nth_or_last_using_find?(args)
          if args.first.is_a?(Hash)
            true
          else
            !(loaded? ||
              owner.new_record? ||
              target.any? { |record| record.new_record? || record.changed? })
          end
        end

        def include_in_memory?(record)
          if reflection.is_a?(ActiveRecord::Reflection::ThroughReflection)
            assoc = owner.association(reflection.through_reflection.name)
            assoc.reader.any? { |source|
              #nodyna <send-874> <SD COMPLEX (change-prone variables)>
              target_association = source.send(reflection.source_reflection.name)

              if target_association.respond_to?(:include?)
                target_association.include?(record)
              else
                target_association == record
              end
            } || target.include?(record)
          else
            target.include?(record)
          end
        end

        def find_by_scan(*args)
          expects_array = args.first.kind_of?(Array)
          ids           = args.flatten.compact.map{ |arg| arg.to_s }.uniq

          if ids.size == 1
            id = ids.first
            record = load_target.detect { |r| id == r.id.to_s }
            expects_array ? [ record ] : record
          else
            load_target.select { |r| ids.include?(r.id.to_s) }
          end
        end

        def first_nth_or_last(type, *args)
          args.shift if args.first.is_a?(Hash) && args.first.empty?

          collection = fetch_first_nth_or_last_using_find?(args) ? scope : load_target
          #nodyna <send-875> <SD MODERATE (change-prone variables)>
          collection.send(type, *args).tap do |record|
            set_inverse_instance record if record.is_a? ActiveRecord::Base
          end
        end
    end
  end
end
