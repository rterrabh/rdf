require 'active_support/core_ext/hash/except'
require 'active_support/core_ext/object/try'
require 'active_support/core_ext/hash/indifferent_access'

module ActiveRecord
  module NestedAttributes #:nodoc:
    class TooManyRecords < ActiveRecordError
    end

    extend ActiveSupport::Concern

    included do
      class_attribute :nested_attributes_options, instance_writer: false
      self.nested_attributes_options = {}
    end

    module ClassMethods
      REJECT_ALL_BLANK_PROC = proc { |attributes| attributes.all? { |key, value| key == '_destroy' || value.blank? } }

      def accepts_nested_attributes_for(*attr_names)
        options = { :allow_destroy => false, :update_only => false }
        options.update(attr_names.extract_options!)
        options.assert_valid_keys(:allow_destroy, :reject_if, :limit, :update_only)
        options[:reject_if] = REJECT_ALL_BLANK_PROC if options[:reject_if] == :all_blank

        attr_names.each do |association_name|
          if reflection = _reflect_on_association(association_name)
            reflection.autosave = true
            define_autosave_validation_callbacks(reflection)

            nested_attributes_options = self.nested_attributes_options.dup
            nested_attributes_options[association_name.to_sym] = options
            self.nested_attributes_options = nested_attributes_options

            type = (reflection.collection? ? :collection : :one_to_one)
            generate_association_writer(association_name, type)
          else
            raise ArgumentError, "No association found for name `#{association_name}'. Has it been defined yet?"
          end
        end
      end

      private

      def generate_association_writer(association_name, type)
        #nodyna <module_eval-840> <ME COMPLEX (define methods)>
        generated_association_methods.module_eval <<-eoruby, __FILE__, __LINE__ + 1
          if method_defined?(:#{association_name}_attributes=)
            remove_method(:#{association_name}_attributes=)
          end
          def #{association_name}_attributes=(attributes)
            assign_nested_attributes_for_#{type}_association(:#{association_name}, attributes)
          end
        eoruby
      end
    end

    def _destroy
      marked_for_destruction?
    end

    private

    UNASSIGNABLE_KEYS = %w( id _destroy )

    def assign_nested_attributes_for_one_to_one_association(association_name, attributes)
      options = self.nested_attributes_options[association_name]
      attributes = attributes.with_indifferent_access
      #nodyna <send-841> <SD COMPLEX (change-prone variables)>
      existing_record = send(association_name)

      if (options[:update_only] || !attributes['id'].blank?) && existing_record &&
          (options[:update_only] || existing_record.id.to_s == attributes['id'].to_s)
        assign_to_or_mark_for_destruction(existing_record, attributes, options[:allow_destroy]) unless call_reject_if(association_name, attributes)

      elsif attributes['id'].present?
        raise_nested_attributes_record_not_found!(association_name, attributes['id'])

      elsif !reject_new_record?(association_name, attributes)
        assignable_attributes = attributes.except(*UNASSIGNABLE_KEYS)

        if existing_record && existing_record.new_record?
          existing_record.assign_attributes(assignable_attributes)
          association(association_name).initialize_attributes(existing_record)
        else
          method = "build_#{association_name}"
          if respond_to?(method)
            #nodyna <send-842> <SD COMPLEX (change-prone variables)>
            send(method, assignable_attributes)
          else
            raise ArgumentError, "Cannot build association `#{association_name}'. Are you trying to build a polymorphic one-to-one association?"
          end
        end
      end
    end

    def assign_nested_attributes_for_collection_association(association_name, attributes_collection)
      options = self.nested_attributes_options[association_name]

      unless attributes_collection.is_a?(Hash) || attributes_collection.is_a?(Array)
        raise ArgumentError, "Hash or Array expected, got #{attributes_collection.class.name} (#{attributes_collection.inspect})"
      end

      check_record_limit!(options[:limit], attributes_collection)

      if attributes_collection.is_a? Hash
        keys = attributes_collection.keys
        attributes_collection = if keys.include?('id') || keys.include?(:id)
          [attributes_collection]
        else
          attributes_collection.values
        end
      end

      association = association(association_name)

      existing_records = if association.loaded?
        association.target
      else
        attribute_ids = attributes_collection.map {|a| a['id'] || a[:id] }.compact
        attribute_ids.empty? ? [] : association.scope.where(association.klass.primary_key => attribute_ids)
      end

      attributes_collection.each do |attributes|
        attributes = attributes.with_indifferent_access

        if attributes['id'].blank?
          unless reject_new_record?(association_name, attributes)
            association.build(attributes.except(*UNASSIGNABLE_KEYS))
          end
        elsif existing_record = existing_records.detect { |record| record.id.to_s == attributes['id'].to_s }
          unless call_reject_if(association_name, attributes)
            target_record = association.target.detect { |record| record.id.to_s == attributes['id'].to_s }
            if target_record
              existing_record = target_record
            else
              association.add_to_target(existing_record, :skip_callbacks)
            end

            assign_to_or_mark_for_destruction(existing_record, attributes, options[:allow_destroy])
          end
        else
          raise_nested_attributes_record_not_found!(association_name, attributes['id'])
        end
      end
    end

    def check_record_limit!(limit, attributes_collection)
      if limit
        limit = case limit
        when Symbol
          #nodyna <send-843> <SD COMPLEX (change-prone variables)>
          send(limit)
        when Proc
          limit.call
        else
          limit
        end

        if limit && attributes_collection.size > limit
          raise TooManyRecords, "Maximum #{limit} records are allowed. Got #{attributes_collection.size} records instead."
        end
      end
    end

    def assign_to_or_mark_for_destruction(record, attributes, allow_destroy)
      record.assign_attributes(attributes.except(*UNASSIGNABLE_KEYS))
      record.mark_for_destruction if has_destroy_flag?(attributes) && allow_destroy
    end

    def has_destroy_flag?(hash)
      Type::Boolean.new.type_cast_from_user(hash['_destroy'])
    end

    def reject_new_record?(association_name, attributes)
      has_destroy_flag?(attributes) || call_reject_if(association_name, attributes)
    end

    def call_reject_if(association_name, attributes)
      return false if has_destroy_flag?(attributes)
      case callback = self.nested_attributes_options[association_name][:reject_if]
      when Symbol
        #nodyna <send-844> <SD COMPLEX (change-prone variables)>
        #nodyna <send-845> <SD COMPLEX (change-prone variables)>
        method(callback).arity == 0 ? send(callback) : send(callback, attributes)
      when Proc
        callback.call(attributes)
      end
    end

    def raise_nested_attributes_record_not_found!(association_name, record_id)
      raise RecordNotFound, "Couldn't find #{self.class._reflect_on_association(association_name).klass.name} with ID=#{record_id} for #{self.class.name} with ID=#{id}"
    end
  end
end
