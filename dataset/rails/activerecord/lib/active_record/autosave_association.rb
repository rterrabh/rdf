module ActiveRecord

  module AutosaveAssociation
    extend ActiveSupport::Concern

    module AssociationBuilderExtension #:nodoc:
      def self.build(model, reflection)
        #nodyna <send-864> <SD EASY (private methods)>
        model.send(:add_autosave_association_callbacks, reflection)
      end

      def self.valid_options
        [ :autosave ]
      end
    end

    included do
      Associations::Builder::Association.extensions << AssociationBuilderExtension
    end

    module ClassMethods
      private

        def define_non_cyclic_method(name, &block)
          return if method_defined?(name)
          #nodyna <define_method-865> <DM COMPLEX (events)>
          define_method(name) do |*args|
            result = true; @_already_called ||= {}
            unless @_already_called[name]
              begin
                @_already_called[name]=true
                #nodyna <instance_eval-866> <IEV MODERATE (block execution)>
                result = instance_eval(&block)
              ensure
                @_already_called[name]=false
              end
            end

            result
          end
        end

        def add_autosave_association_callbacks(reflection)
          save_method = :"autosave_associated_records_for_#{reflection.name}"

          if reflection.collection?
            before_save :before_save_collection_association

            define_non_cyclic_method(save_method) { save_collection_association(reflection) }
            after_create save_method
            after_update save_method
          elsif reflection.has_one?
            #nodyna <define_method-867> <DM COMPLEX (events)>
            define_method(save_method) { save_has_one_association(reflection) } unless method_defined?(save_method)
            after_create save_method
            after_update save_method
          else
            define_non_cyclic_method(save_method) { save_belongs_to_association(reflection) }
            before_save save_method
          end

          define_autosave_validation_callbacks(reflection)
        end

        def define_autosave_validation_callbacks(reflection)
          validation_method = :"validate_associated_records_for_#{reflection.name}"
          if reflection.validate? && !method_defined?(validation_method)
            if reflection.collection?
              method = :validate_collection_association
            else
              method = :validate_single_association
            end

            #nodyna <send-868> <SD EASY (change-prone variables)>
            define_non_cyclic_method(validation_method) { send(method, reflection) }
            validate validation_method
          end
        end
    end

    def reload(options = nil)
      @marked_for_destruction = false
      @destroyed_by_association = nil
      super
    end

    def mark_for_destruction
      @marked_for_destruction = true
    end

    def marked_for_destruction?
      @marked_for_destruction
    end

    def destroyed_by_association=(reflection)
      @destroyed_by_association = reflection
    end

    def destroyed_by_association
      @destroyed_by_association
    end

    def changed_for_autosave?
      new_record? || changed? || marked_for_destruction? || nested_records_changed_for_autosave?
    end

    private

      def associated_records_to_validate_or_save(association, new_record, autosave)
        if new_record
          association && association.target
        elsif autosave
          association.target.find_all { |record| record.changed_for_autosave? }
        else
          association.target.find_all { |record| record.new_record? }
        end
      end

      def nested_records_changed_for_autosave?
        @_nested_records_changed_for_autosave_already_called ||= false
        return false if @_nested_records_changed_for_autosave_already_called
        begin
          @_nested_records_changed_for_autosave_already_called = true
          self.class._reflections.values.any? do |reflection|
            if reflection.options[:autosave]
              association = association_instance_get(reflection.name)
              association && Array.wrap(association.target).any?(&:changed_for_autosave?)
            end
          end
        ensure
          @_nested_records_changed_for_autosave_already_called = false
        end
      end

      def validate_single_association(reflection)
        association = association_instance_get(reflection.name)
        record      = association && association.reader
        association_valid?(reflection, record) if record
      end

      def validate_collection_association(reflection)
        if association = association_instance_get(reflection.name)
          if records = associated_records_to_validate_or_save(association, new_record?, reflection.options[:autosave])
            records.each { |record| association_valid?(reflection, record) }
          end
        end
      end

      def association_valid?(reflection, record)
        return true if record.destroyed? || (reflection.options[:autosave] && record.marked_for_destruction?)

        validation_context = self.validation_context unless [:create, :update].include?(self.validation_context)
        unless valid = record.valid?(validation_context)
          if reflection.options[:autosave]
            record.errors.each do |attribute, message|
              attribute = "#{reflection.name}.#{attribute}"
              errors[attribute] << message
              errors[attribute].uniq!
            end
          else
            errors.add(reflection.name)
          end
        end
        valid
      end

      def before_save_collection_association
        @new_record_before_save = new_record?
        true
      end

      def save_collection_association(reflection)
        if association = association_instance_get(reflection.name)
          autosave = reflection.options[:autosave]

          if records = associated_records_to_validate_or_save(association, @new_record_before_save, autosave)
            if autosave
              records_to_destroy = records.select(&:marked_for_destruction?)
              records_to_destroy.each { |record| association.destroy(record) }
              records -= records_to_destroy
            end

            records.each do |record|
              next if record.destroyed?

              saved = true

              if autosave != false && (@new_record_before_save || record.new_record?)
                if autosave
                  saved = association.insert_record(record, false)
                else
                  association.insert_record(record) unless reflection.nested?
                end
              elsif autosave
                saved = record.save(:validate => false)
              end

              raise ActiveRecord::Rollback unless saved
            end
          end

          association.reset_scope if association.respond_to?(:reset_scope)
        end
      end

      def save_has_one_association(reflection)
        association = association_instance_get(reflection.name)
        record      = association && association.load_target

        if record && !record.destroyed?
          autosave = reflection.options[:autosave]

          if autosave && record.marked_for_destruction?
            record.destroy
          elsif autosave != false
            #nodyna <send-869> <SD COMPLEX (change-prone variables)>
            key = reflection.options[:primary_key] ? send(reflection.options[:primary_key]) : id

            if (autosave && record.changed_for_autosave?) || new_record? || record_changed?(reflection, record, key)
              unless reflection.through_reflection
                record[reflection.foreign_key] = key
              end

              saved = record.save(:validate => !autosave)
              raise ActiveRecord::Rollback if !saved && autosave
              saved
            end
          end
        end
      end

      def record_changed?(reflection, record, key)
        record.new_record? ||
          (record.has_attribute?(reflection.foreign_key) && record[reflection.foreign_key] != key) ||
          record.attribute_changed?(reflection.foreign_key)
      end

      def save_belongs_to_association(reflection)
        association = association_instance_get(reflection.name)
        record      = association && association.load_target
        if record && !record.destroyed?
          autosave = reflection.options[:autosave]

          if autosave && record.marked_for_destruction?
            self[reflection.foreign_key] = nil
            record.destroy
          elsif autosave != false
            saved = record.save(:validate => !autosave) if record.new_record? || (autosave && record.changed_for_autosave?)

            if association.updated?
              #nodyna <send-870> <SD COMPLEX (change-prone variables)>
              association_id = record.send(reflection.options[:primary_key] || :id)
              self[reflection.foreign_key] = association_id
              association.loaded!
            end

            saved if autosave
          end
        end
      end
  end
end
