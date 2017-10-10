require 'thread'
require 'active_support/core_ext/string/filters'

module ActiveRecord
  module Reflection # :nodoc:
    extend ActiveSupport::Concern

    included do
      class_attribute :_reflections
      class_attribute :aggregate_reflections
      self._reflections = {}
      self.aggregate_reflections = {}
    end

    def self.create(macro, name, scope, options, ar)
      klass = case macro
              when :composed_of
                AggregateReflection
              when :has_many
                HasManyReflection
              when :has_one
                HasOneReflection
              when :belongs_to
                BelongsToReflection
              else
                raise "Unsupported Macro: #{macro}"
              end

      reflection = klass.new(name, scope, options, ar)
      options[:through] ? ThroughReflection.new(reflection) : reflection
    end

    def self.add_reflection(ar, name, reflection)
      ar._reflections = ar._reflections.merge(name.to_s => reflection)
    end

    def self.add_aggregate_reflection(ar, name, reflection)
      ar.aggregate_reflections = ar.aggregate_reflections.merge(name.to_s => reflection)
    end

    module ClassMethods
      def reflect_on_all_aggregations
        aggregate_reflections.values
      end

      def reflect_on_aggregation(aggregation)
        aggregate_reflections[aggregation.to_s]
      end

      def reflections
        ref = {}
        _reflections.each do |name, reflection|
          parent_name, parent_reflection = reflection.parent_reflection
          if parent_name
            ref[parent_name] = parent_reflection
          else
            ref[name] = reflection
          end
        end
        ref
      end

      def reflect_on_all_associations(macro = nil)
        association_reflections = reflections.values
        macro ? association_reflections.select { |reflection| reflection.macro == macro } : association_reflections
      end

      def reflect_on_association(association)
        reflections[association.to_s]
      end

      def _reflect_on_association(association) #:nodoc:
        _reflections[association.to_s]
      end

      def reflect_on_all_autosave_associations
        reflections.values.select { |reflection| reflection.options[:autosave] }
      end
    end

    class AbstractReflection # :nodoc:
      def table_name
        klass.table_name
      end

      def build_association(attributes, &block)
        klass.new(attributes, &block)
      end

      def quoted_table_name
        klass.quoted_table_name
      end

      def primary_key_type
        klass.type_for_attribute(klass.primary_key)
      end

      def class_name
        @class_name ||= (options[:class_name] || derive_class_name).to_s
      end

      JoinKeys = Struct.new(:key, :foreign_key) # :nodoc:

      def join_keys(assoc_klass)
        JoinKeys.new(foreign_key, active_record_primary_key)
      end

      def source_macro
        ActiveSupport::Deprecation.warn(<<-MSG.squish)
          ActiveRecord::Base.source_macro is deprecated and will be removed
          without replacement.
        MSG

        macro
      end
    end
    class MacroReflection < AbstractReflection
      attr_reader :name

      attr_reader :scope

      attr_reader :options

      attr_reader :active_record

      attr_reader :plural_name # :nodoc:

      def initialize(name, scope, options, active_record)
        @name          = name
        @scope         = scope
        @options       = options
        @active_record = active_record
        @klass         = options[:anonymous_class]
        @plural_name   = active_record.pluralize_table_names ?
                            name.to_s.pluralize : name.to_s
      end

      def autosave=(autosave)
        @automatic_inverse_of = false
        @options[:autosave] = autosave
        _, parent_reflection = self.parent_reflection
        if parent_reflection
          parent_reflection.autosave = autosave
        end
      end

      def klass
        @klass ||= compute_class(class_name)
      end

      def compute_class(name)
        name.constantize
      end

      def ==(other_aggregation)
        super ||
          other_aggregation.kind_of?(self.class) &&
          name == other_aggregation.name &&
          !other_aggregation.options.nil? &&
          active_record == other_aggregation.active_record
      end

      private
        def derive_class_name
          name.to_s.camelize
        end
    end


    class AggregateReflection < MacroReflection #:nodoc:
      def mapping
        mapping = options[:mapping] || [name, name]
        mapping.first.is_a?(Array) ? mapping : [mapping]
      end
    end

    class AssociationReflection < MacroReflection #:nodoc:
      def klass
        @klass ||= compute_class(class_name)
      end

      def compute_class(name)
        #nodyna <send-921> <SD EASY (private methods)>
        active_record.send(:compute_type, name)
      end

      attr_reader :type, :foreign_type
      attr_accessor :parent_reflection # [:name, Reflection]

      def initialize(name, scope, options, active_record)
        super
        @automatic_inverse_of = nil
        @type         = options[:as] && (options[:foreign_type] || "#{options[:as]}_type")
        @foreign_type = options[:foreign_type] || "#{name}_type"
        @constructable = calculate_constructable(macro, options)
        @association_scope_cache = {}
        @scope_lock = Mutex.new
      end

      def association_scope_cache(conn, owner)
        key = conn.prepared_statements
        if polymorphic?
          key = [key, owner._read_attribute(@foreign_type)]
        end
        @association_scope_cache[key] ||= @scope_lock.synchronize {
          @association_scope_cache[key] ||= yield
        }
      end

      def constructable? # :nodoc:
        @constructable
      end

      def join_table
        @join_table ||= options[:join_table] || derive_join_table
      end

      def foreign_key
        @foreign_key ||= options[:foreign_key] || derive_foreign_key
      end

      def association_foreign_key
        @association_foreign_key ||= options[:association_foreign_key] || class_name.foreign_key
      end

      def association_primary_key(klass = nil)
        options[:primary_key] || primary_key(klass || self.klass)
      end

      def active_record_primary_key
        @active_record_primary_key ||= options[:primary_key] || primary_key(active_record)
      end

      def counter_cache_column
        if options[:counter_cache] == true
          "#{active_record.name.demodulize.underscore.pluralize}_count"
        elsif options[:counter_cache]
          options[:counter_cache].to_s
        end
      end

      def check_validity!
        check_validity_of_inverse!
      end

      def check_validity_of_inverse!
        unless polymorphic?
          if has_inverse? && inverse_of.nil?
            raise InverseOfAssociationNotFoundError.new(self)
          end
        end
      end

      def check_preloadable!
        return unless scope

        if scope.arity > 0
          ActiveSupport::Deprecation.warn(<<-MSG.squish)
            The association scope '#{name}' is instance dependent (the scope
            block takes an argument). Preloading happens before the individual
            instances are created. This means that there is no instance being
            passed to the association scope. This will most likely result in
            broken or incorrect behavior. Joining, Preloading and eager loading
            of these associations is deprecated and will be removed in the future.
          MSG
        end
      end
      alias :check_eager_loadable! :check_preloadable!

      def join_id_for(owner) # :nodoc:
        owner[active_record_primary_key]
      end

      def through_reflection
        nil
      end

      def source_reflection
        self
      end

      def chain
        [self]
      end

      def nested?
        false
      end

      def scope_chain
        scope ? [[scope]] : [[]]
      end

      def has_inverse?
        inverse_name
      end

      def inverse_of
        return unless inverse_name

        @inverse_of ||= klass._reflect_on_association inverse_name
      end

      def polymorphic_inverse_of(associated_class)
        if has_inverse?
          if inverse_relationship = associated_class._reflect_on_association(options[:inverse_of])
            inverse_relationship
          else
            raise InverseOfAssociationNotFoundError.new(self, associated_class)
          end
        end
      end

      def macro; raise NotImplementedError; end

      def collection?
        false
      end

      def validate?
        !options[:validate].nil? ? options[:validate] : (options[:autosave] == true || collection?)
      end

      def belongs_to?; false; end

      def has_one?; false; end

      def association_class
        case macro
        when :belongs_to
          if polymorphic?
            Associations::BelongsToPolymorphicAssociation
          else
            Associations::BelongsToAssociation
          end
        when :has_many
          if options[:through]
            Associations::HasManyThroughAssociation
          else
            Associations::HasManyAssociation
          end
        when :has_one
          if options[:through]
            Associations::HasOneThroughAssociation
          else
            Associations::HasOneAssociation
          end
        end
      end

      def polymorphic?
        options[:polymorphic]
      end

      VALID_AUTOMATIC_INVERSE_MACROS = [:has_many, :has_one, :belongs_to]
      INVALID_AUTOMATIC_INVERSE_OPTIONS = [:conditions, :through, :polymorphic, :foreign_key]

      protected

        def actual_source_reflection # FIXME: this is a horrible name
          self
        end

      private

        def calculate_constructable(macro, options)
          case macro
          when :belongs_to
            !polymorphic?
          when :has_one
            !options[:through]
          else
            true
          end
        end

        def inverse_name
          options.fetch(:inverse_of) do
            if @automatic_inverse_of == false
              nil
            else
              @automatic_inverse_of ||= automatic_inverse_of
            end
          end
        end

        def automatic_inverse_of
          if can_find_inverse_of_automatically?(self)
            inverse_name = ActiveSupport::Inflector.underscore(options[:as] || active_record.name.demodulize).to_sym

            begin
              reflection = klass._reflect_on_association(inverse_name)
            rescue NameError
              reflection = false
            end

            if valid_inverse_reflection?(reflection)
              return inverse_name
            end
          end

          false
        end

        def valid_inverse_reflection?(reflection)
          reflection &&
            klass.name == reflection.active_record.name &&
            can_find_inverse_of_automatically?(reflection)
        end

        def can_find_inverse_of_automatically?(reflection)
          reflection.options[:inverse_of] != false &&
            VALID_AUTOMATIC_INVERSE_MACROS.include?(reflection.macro) &&
            !INVALID_AUTOMATIC_INVERSE_OPTIONS.any? { |opt| reflection.options[opt] } &&
            !reflection.scope
        end

        def derive_class_name
          class_name = name.to_s
          class_name = class_name.singularize if collection?
          class_name.camelize
        end

        def derive_foreign_key
          if belongs_to?
            "#{name}_id"
          elsif options[:as]
            "#{options[:as]}_id"
          else
            active_record.name.foreign_key
          end
        end

        def derive_join_table
          ModelSchema.derive_join_table_name active_record.table_name, klass.table_name
        end

        def primary_key(klass)
          klass.primary_key || raise(UnknownPrimaryKey.new(klass))
        end
    end

    class HasManyReflection < AssociationReflection # :nodoc:
      def initialize(name, scope, options, active_record)
        super(name, scope, options, active_record)
      end

      def macro; :has_many; end

      def collection?; true; end
    end

    class HasOneReflection < AssociationReflection # :nodoc:
      def initialize(name, scope, options, active_record)
        super(name, scope, options, active_record)
      end

      def macro; :has_one; end

      def has_one?; true; end
    end

    class BelongsToReflection < AssociationReflection # :nodoc:
      def initialize(name, scope, options, active_record)
        super(name, scope, options, active_record)
      end

      def macro; :belongs_to; end

      def belongs_to?; true; end

      def join_keys(assoc_klass)
        key = polymorphic? ? association_primary_key(assoc_klass) : association_primary_key
        JoinKeys.new(key, foreign_key)
      end

      def join_id_for(owner) # :nodoc:
        owner[foreign_key]
      end
    end

    class HasAndBelongsToManyReflection < AssociationReflection # :nodoc:
      def initialize(name, scope, options, active_record)
        super
      end

      def macro; :has_and_belongs_to_many; end

      def collection?
        true
      end
    end

    class ThroughReflection < AbstractReflection #:nodoc:
      attr_reader :delegate_reflection
      delegate :foreign_key, :foreign_type, :association_foreign_key,
               :active_record_primary_key, :type, :to => :source_reflection

      def initialize(delegate_reflection)
        @delegate_reflection = delegate_reflection
        @klass         = delegate_reflection.options[:anonymous_class]
        @source_reflection_name = delegate_reflection.options[:source]
      end

      def klass
        @klass ||= delegate_reflection.compute_class(class_name)
      end

      def source_reflection
        through_reflection.klass._reflect_on_association(source_reflection_name)
      end

      def through_reflection
        active_record._reflect_on_association(options[:through])
      end

      def chain
        @chain ||= begin
          a = source_reflection.chain
          b = through_reflection.chain
          chain = a + b
          chain[0] = self # Use self so we don't lose the information from :source_type
          chain
        end
      end

      def scope_chain
        @scope_chain ||= begin
          scope_chain = source_reflection.scope_chain.map(&:dup)

          scope_chain.first << scope if scope

          through_scope_chain = through_reflection.scope_chain.map(&:dup)

          if options[:source_type]
            type = foreign_type
            source_type = options[:source_type]
            through_scope_chain.first << lambda { |object|
              where(type => source_type)
            }
          end

          scope_chain + through_scope_chain
        end
      end

      def join_keys(assoc_klass)
        source_reflection.join_keys(assoc_klass)
      end

      def source_macro
        ActiveSupport::Deprecation.warn(<<-MSG.squish)
          ActiveRecord::Base.source_macro is deprecated and will be removed
          without replacement.
        MSG

        source_reflection.source_macro
      end

      def nested?
        chain.length > 2
      end

      def association_primary_key(klass = nil)
        actual_source_reflection.options[:primary_key] || primary_key(klass || self.klass)
      end

      def source_reflection_names
        options[:source] ? [options[:source]] : [name.to_s.singularize, name].uniq
      end

      def source_reflection_name # :nodoc:
        return @source_reflection_name if @source_reflection_name

        names = [name.to_s.singularize, name].collect { |n| n.to_sym }.uniq
        names = names.find_all { |n|
          through_reflection.klass._reflect_on_association(n)
        }

        if names.length > 1
          example_options = options.dup
          example_options[:source] = source_reflection_names.first
          ActiveSupport::Deprecation.warn \
            "Ambiguous source reflection for through association.  Please " \
            "specify a :source directive on your declaration like:\n" \
            "\n" \
            "  class #{active_record.name} < ActiveRecord::Base\n" \
            "    #{macro} :#{name}, #{example_options}\n" \
            "  end"
        end

        @source_reflection_name = names.first
      end

      def source_options
        source_reflection.options
      end

      def through_options
        through_reflection.options
      end

      def join_id_for(owner) # :nodoc:
        source_reflection.join_id_for(owner)
      end

      def check_validity!
        if through_reflection.nil?
          raise HasManyThroughAssociationNotFoundError.new(active_record.name, self)
        end

        if through_reflection.polymorphic?
          if has_one?
            raise HasOneAssociationPolymorphicThroughError.new(active_record.name, self)
          else
            raise HasManyThroughAssociationPolymorphicThroughError.new(active_record.name, self)
          end
        end

        if source_reflection.nil?
          raise HasManyThroughSourceAssociationNotFoundError.new(self)
        end

        if options[:source_type] && !source_reflection.polymorphic?
          raise HasManyThroughAssociationPointlessSourceTypeError.new(active_record.name, self, source_reflection)
        end

        if source_reflection.polymorphic? && options[:source_type].nil?
          raise HasManyThroughAssociationPolymorphicSourceError.new(active_record.name, self, source_reflection)
        end

        if has_one? && through_reflection.collection?
          raise HasOneThroughCantAssociateThroughCollection.new(active_record.name, self, through_reflection)
        end

        check_validity_of_inverse!
      end

      protected

        def actual_source_reflection # FIXME: this is a horrible name
          #nodyna <send-922> <SD EASY (private methods)>
          source_reflection.send(:actual_source_reflection)
        end

        def primary_key(klass)
          klass.primary_key || raise(UnknownPrimaryKey.new(klass))
        end

      private
        def derive_class_name
          options[:source_type] || source_reflection.class_name
        end

        delegate_methods = AssociationReflection.public_instance_methods -
          public_instance_methods

        delegate(*delegate_methods, to: :delegate_reflection)

    end
  end
end
