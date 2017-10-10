module ActiveRecord
  module Persistence
    extend ActiveSupport::Concern

    module ClassMethods
      def create(attributes = nil, &block)
        if attributes.is_a?(Array)
          attributes.collect { |attr| create(attr, &block) }
        else
          object = new(attributes, &block)
          object.save
          object
        end
      end

      def create!(attributes = nil, &block)
        if attributes.is_a?(Array)
          attributes.collect { |attr| create!(attr, &block) }
        else
          object = new(attributes, &block)
          object.save!
          object
        end
      end

      def instantiate(attributes, column_types = {})
        klass = discriminate_class_for_record(attributes)
        attributes = klass.attributes_builder.build_from_database(attributes, column_types)
        klass.allocate.init_with('attributes' => attributes, 'new_record' => false)
      end

      private
        def discriminate_class_for_record(record)
          self
        end
    end

    def new_record?
      sync_with_transaction_state
      @new_record
    end

    def destroyed?
      sync_with_transaction_state
      @destroyed
    end

    def persisted?
      !(new_record? || destroyed?)
    end

    def save(*)
      create_or_update
    rescue ActiveRecord::RecordInvalid
      false
    end

    def save!(*)
      create_or_update || raise(RecordNotSaved.new("Failed to save the record", self))
    end

    def delete
      self.class.delete(id) if persisted?
      @destroyed = true
      freeze
    end

    def destroy
      raise ReadOnlyRecord, "#{self.class} is marked as readonly" if readonly?
      destroy_associations
      self.class.connection.add_transaction_record(self)
      destroy_row if persisted?
      @destroyed = true
      freeze
    end

    def destroy!
      destroy || raise(RecordNotDestroyed.new("Failed to destroy the record", self))
    end

    def becomes(klass)
      became = klass.new
      #nodyna <instance_variable_set-799> <not yet classified>
      became.instance_variable_set("@attributes", @attributes)
      changed_attributes = @changed_attributes if defined?(@changed_attributes)
      #nodyna <instance_variable_set-800> <not yet classified>
      became.instance_variable_set("@changed_attributes", changed_attributes || {})
      #nodyna <instance_variable_set-801> <not yet classified>
      became.instance_variable_set("@new_record", new_record?)
      #nodyna <instance_variable_set-802> <not yet classified>
      became.instance_variable_set("@destroyed", destroyed?)
      #nodyna <instance_variable_set-803> <not yet classified>
      became.instance_variable_set("@errors", errors)
      became
    end

    def becomes!(klass)
      became = becomes(klass)
      sti_type = nil
      if !klass.descends_from_active_record?
        sti_type = klass.sti_name
      end
      #nodyna <send-804> <SD COMPLEX (change-prone variables)>
      became.public_send("#{klass.inheritance_column}=", sti_type)
      became
    end

    def update_attribute(name, value)
      name = name.to_s
      verify_readonly_attribute(name)
      #nodyna <send-805> <SD COMPLEX (change-prone variables)>
      send("#{name}=", value)
      save(validate: false)
    end

    def update(attributes)
      with_transaction_returning_status do
        assign_attributes(attributes)
        save
      end
    end

    alias update_attributes update

    def update!(attributes)
      with_transaction_returning_status do
        assign_attributes(attributes)
        save!
      end
    end

    alias update_attributes! update!

    def update_column(name, value)
      update_columns(name => value)
    end

    def update_columns(attributes)
      raise ActiveRecordError, "cannot update a new record" if new_record?
      raise ActiveRecordError, "cannot update a destroyed record" if destroyed?

      attributes.each_key do |key|
        verify_readonly_attribute(key.to_s)
      end

      updated_count = self.class.unscoped.where(self.class.primary_key => id).update_all(attributes)

      attributes.each do |k, v|
        raw_write_attribute(k, v)
      end

      updated_count == 1
    end

    def increment(attribute, by = 1)
      self[attribute] ||= 0
      self[attribute] += by
      self
    end

    def increment!(attribute, by = 1)
      increment(attribute, by).update_attribute(attribute, self[attribute])
    end

    def decrement(attribute, by = 1)
      self[attribute] ||= 0
      self[attribute] -= by
      self
    end

    def decrement!(attribute, by = 1)
      decrement(attribute, by).update_attribute(attribute, self[attribute])
    end

    def toggle(attribute)
      #nodyna <send-806> <SD COMPLEX (change-prone variables)>
      self[attribute] = !send("#{attribute}?")
      self
    end

    def toggle!(attribute)
      toggle(attribute).update_attribute(attribute, self[attribute])
    end

    def reload(options = nil)
      clear_aggregation_cache
      clear_association_cache
      self.class.connection.clear_query_cache

      fresh_object =
        if options && options[:lock]
          self.class.unscoped { self.class.lock(options[:lock]).find(id) }
        else
          self.class.unscoped { self.class.find(id) }
        end

      #nodyna <instance_variable_get-807> <not yet classified>
      @attributes = fresh_object.instance_variable_get('@attributes')
      @new_record = false
      self
    end

    def touch(*names)
      raise ActiveRecordError, "cannot touch on a new record object" unless persisted?

      attributes = timestamp_attributes_for_update_in_model
      attributes.concat(names)

      unless attributes.empty?
        current_time = current_time_from_proper_timezone
        changes = {}

        attributes.each do |column|
          column = column.to_s
          changes[column] = write_attribute(column, current_time)
        end

        changes[self.class.locking_column] = increment_lock if locking_enabled?

        clear_attribute_changes(changes.keys)
        primary_key = self.class.primary_key
        self.class.unscoped.where(primary_key => self[primary_key]).update_all(changes) == 1
      else
        true
      end
    end

  private

    def destroy_associations
    end

    def destroy_row
      relation_for_destroy.delete_all
    end

    def relation_for_destroy
      pk         = self.class.primary_key
      column     = self.class.columns_hash[pk]
      substitute = self.class.connection.substitute_at(column)

      relation = self.class.unscoped.where(
        self.class.arel_table[pk].eq(substitute))

      relation.bind_values = [[column, id]]
      relation
    end

    def create_or_update
      raise ReadOnlyRecord, "#{self.class} is marked as readonly" if readonly?
      result = new_record? ? _create_record : _update_record
      result != false
    end

    def _update_record(attribute_names = self.attribute_names)
      attributes_values = arel_attributes_with_values_for_update(attribute_names)
      if attributes_values.empty?
        0
      else
        self.class.unscoped._update_record attributes_values, id, id_was
      end
    end

    def _create_record(attribute_names = self.attribute_names)
      attributes_values = arel_attributes_with_values_for_create(attribute_names)

      new_id = self.class.unscoped.insert attributes_values
      self.id ||= new_id if self.class.primary_key

      @new_record = false
      id
    end

    def verify_readonly_attribute(name)
      raise ActiveRecordError, "#{name} is marked as readonly" if self.class.readonly_attributes.include?(name)
    end
  end
end
