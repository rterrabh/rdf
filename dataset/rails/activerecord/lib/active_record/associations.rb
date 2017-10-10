require 'active_support/core_ext/enumerable'
require 'active_support/core_ext/string/conversions'
require 'active_support/core_ext/module/remove_method'
require 'active_record/errors'

module ActiveRecord
  class AssociationNotFoundError < ConfigurationError #:nodoc:
    def initialize(record, association_name)
      super("Association named '#{association_name}' was not found on #{record.class.name}; perhaps you misspelled it?")
    end
  end

  class InverseOfAssociationNotFoundError < ActiveRecordError #:nodoc:
    def initialize(reflection, associated_class = nil)
      super("Could not find the inverse association for #{reflection.name} (#{reflection.options[:inverse_of].inspect} in #{associated_class.nil? ? reflection.class_name : associated_class.name})")
    end
  end

  class HasManyThroughAssociationNotFoundError < ActiveRecordError #:nodoc:
    def initialize(owner_class_name, reflection)
      super("Could not find the association #{reflection.options[:through].inspect} in model #{owner_class_name}")
    end
  end

  class HasManyThroughAssociationPolymorphicSourceError < ActiveRecordError #:nodoc:
    def initialize(owner_class_name, reflection, source_reflection)
      super("Cannot have a has_many :through association '#{owner_class_name}##{reflection.name}' on the polymorphic object '#{source_reflection.class_name}##{source_reflection.name}' without 'source_type'. Try adding 'source_type: \"#{reflection.name.to_s.classify}\"' to 'has_many :through' definition.")
    end
  end

  class HasManyThroughAssociationPolymorphicThroughError < ActiveRecordError #:nodoc:
    def initialize(owner_class_name, reflection)
      super("Cannot have a has_many :through association '#{owner_class_name}##{reflection.name}' which goes through the polymorphic association '#{owner_class_name}##{reflection.through_reflection.name}'.")
    end
  end

  class HasManyThroughAssociationPointlessSourceTypeError < ActiveRecordError #:nodoc:
    def initialize(owner_class_name, reflection, source_reflection)
      super("Cannot have a has_many :through association '#{owner_class_name}##{reflection.name}' with a :source_type option if the '#{reflection.through_reflection.class_name}##{source_reflection.name}' is not polymorphic. Try removing :source_type on your association.")
    end
  end

  class HasOneThroughCantAssociateThroughCollection < ActiveRecordError #:nodoc:
    def initialize(owner_class_name, reflection, through_reflection)
      super("Cannot have a has_one :through association '#{owner_class_name}##{reflection.name}' where the :through association '#{owner_class_name}##{through_reflection.name}' is a collection. Specify a has_one or belongs_to association in the :through option instead.")
    end
  end

  class HasOneAssociationPolymorphicThroughError < ActiveRecordError #:nodoc:
    def initialize(owner_class_name, reflection)
      super("Cannot have a has_one :through association '#{owner_class_name}##{reflection.name}' which goes through the polymorphic association '#{owner_class_name}##{reflection.through_reflection.name}'.")
    end
  end

  class HasManyThroughSourceAssociationNotFoundError < ActiveRecordError #:nodoc:
    def initialize(reflection)
      through_reflection      = reflection.through_reflection
      source_reflection_names = reflection.source_reflection_names
      source_associations     = reflection.through_reflection.klass._reflections.keys
      super("Could not find the source association(s) #{source_reflection_names.collect{ |a| a.inspect }.to_sentence(:two_words_connector => ' or ', :last_word_connector => ', or ', :locale => :en)} in model #{through_reflection.klass}. Try 'has_many #{reflection.name.inspect}, :through => #{through_reflection.name.inspect}, :source => <name>'. Is it one of #{source_associations.to_sentence(:two_words_connector => ' or ', :last_word_connector => ', or ', :locale => :en)}?")
    end
  end

  class HasManyThroughCantAssociateThroughHasOneOrManyReflection < ActiveRecordError #:nodoc:
    def initialize(owner, reflection)
      super("Cannot modify association '#{owner.class.name}##{reflection.name}' because the source reflection class '#{reflection.source_reflection.class_name}' is associated to '#{reflection.through_reflection.class_name}' via :#{reflection.source_reflection.macro}.")
    end
  end

  class HasManyThroughCantAssociateNewRecords < ActiveRecordError #:nodoc:
    def initialize(owner, reflection)
      super("Cannot associate new records through '#{owner.class.name}##{reflection.name}' on '#{reflection.source_reflection.class_name rescue nil}##{reflection.source_reflection.name rescue nil}'. Both records must have an id in order to create the has_many :through record associating them.")
    end
  end

  class HasManyThroughCantDissociateNewRecords < ActiveRecordError #:nodoc:
    def initialize(owner, reflection)
      super("Cannot dissociate new records through '#{owner.class.name}##{reflection.name}' on '#{reflection.source_reflection.class_name rescue nil}##{reflection.source_reflection.name rescue nil}'. Both records must have an id in order to delete the has_many :through record associating them.")
    end
  end

  class HasManyThroughNestedAssociationsAreReadonly < ActiveRecordError #:nodoc:
    def initialize(owner, reflection)
      super("Cannot modify association '#{owner.class.name}##{reflection.name}' because it goes through more than one other association.")
    end
  end

  class EagerLoadPolymorphicError < ActiveRecordError #:nodoc:
    def initialize(reflection)
      super("Cannot eagerly load the polymorphic association #{reflection.name.inspect}")
    end
  end

  class ReadOnlyAssociation < ActiveRecordError #:nodoc:
    def initialize(reflection)
      super("Cannot add to a has_many :through association. Try adding to #{reflection.through_reflection.name.inspect}.")
    end
  end

  class DeleteRestrictionError < ActiveRecordError #:nodoc:
    def initialize(name)
      super("Cannot delete record because of dependent #{name}")
    end
  end

  module Associations # :nodoc:
    extend ActiveSupport::Autoload
    extend ActiveSupport::Concern

    autoload :Association,           'active_record/associations/association'
    autoload :SingularAssociation,   'active_record/associations/singular_association'
    autoload :CollectionAssociation, 'active_record/associations/collection_association'
    autoload :ForeignAssociation,    'active_record/associations/foreign_association'
    autoload :CollectionProxy,       'active_record/associations/collection_proxy'

    autoload :BelongsToAssociation,            'active_record/associations/belongs_to_association'
    autoload :BelongsToPolymorphicAssociation, 'active_record/associations/belongs_to_polymorphic_association'
    autoload :HasManyAssociation,              'active_record/associations/has_many_association'
    autoload :HasManyThroughAssociation,       'active_record/associations/has_many_through_association'
    autoload :HasOneAssociation,               'active_record/associations/has_one_association'
    autoload :HasOneThroughAssociation,        'active_record/associations/has_one_through_association'
    autoload :ThroughAssociation,              'active_record/associations/through_association'

    module Builder #:nodoc:
      autoload :Association,           'active_record/associations/builder/association'
      autoload :SingularAssociation,   'active_record/associations/builder/singular_association'
      autoload :CollectionAssociation, 'active_record/associations/builder/collection_association'

      autoload :BelongsTo,           'active_record/associations/builder/belongs_to'
      autoload :HasOne,              'active_record/associations/builder/has_one'
      autoload :HasMany,             'active_record/associations/builder/has_many'
      autoload :HasAndBelongsToMany, 'active_record/associations/builder/has_and_belongs_to_many'
    end

    eager_autoload do
      autoload :Preloader,        'active_record/associations/preloader'
      autoload :JoinDependency,   'active_record/associations/join_dependency'
      autoload :AssociationScope, 'active_record/associations/association_scope'
      autoload :AliasTracker,     'active_record/associations/alias_tracker'
    end

    def clear_association_cache #:nodoc:
      @association_cache.clear if persisted?
    end

    attr_reader :association_cache

    def association(name) #:nodoc:
      association = association_instance_get(name)

      if association.nil?
        raise AssociationNotFoundError.new(self, name) unless reflection = self.class._reflect_on_association(name)
        association = reflection.association_class.new(self, reflection)
        association_instance_set(name, association)
      end

      association
    end

    private
      def association_instance_get(name)
        @association_cache[name]
      end

      def association_instance_set(name, association)
        @association_cache[name] = association
      end

    module ClassMethods
      def has_many(name, scope = nil, options = {}, &extension)
        reflection = Builder::HasMany.build(self, name, scope, options, &extension)
        Reflection.add_reflection self, name, reflection
      end

      def has_one(name, scope = nil, options = {})
        reflection = Builder::HasOne.build(self, name, scope, options)
        Reflection.add_reflection self, name, reflection
      end

      def belongs_to(name, scope = nil, options = {})
        reflection = Builder::BelongsTo.build(self, name, scope, options)
        Reflection.add_reflection self, name, reflection
      end

      def has_and_belongs_to_many(name, scope = nil, options = {}, &extension)
        if scope.is_a?(Hash)
          options = scope
          scope   = nil
        end

        habtm_reflection = ActiveRecord::Reflection::HasAndBelongsToManyReflection.new(name, scope, options, self)

        builder = Builder::HasAndBelongsToMany.new name, self, options

        join_model = builder.through_model

        #nodyna <const_set-808> <CS COMPLEX (change-prone variable)>
        const_set join_model.name, join_model

        middle_reflection = builder.middle_reflection join_model

        Builder::HasMany.define_callbacks self, middle_reflection
        Reflection.add_reflection self, middle_reflection.name, middle_reflection
        middle_reflection.parent_reflection = [name.to_s, habtm_reflection]

        include Module.new {
          #nodyna <class_eval-809> <not yet classified>
          class_eval <<-RUBY, __FILE__, __LINE__ + 1
          def destroy_associations
            association(:#{middle_reflection.name}).delete_all(:delete_all)
            association(:#{name}).reset
            super
          end
          RUBY
        }

        hm_options = {}
        hm_options[:through] = middle_reflection.name
        hm_options[:source] = join_model.right_reflection.name

        [:before_add, :after_add, :before_remove, :after_remove, :autosave, :validate, :join_table, :class_name, :extend].each do |k|
          hm_options[k] = options[k] if options.key? k
        end

        has_many name, scope, hm_options, &extension
        self._reflections[name.to_s].parent_reflection = [name.to_s, habtm_reflection]
      end
    end
  end
end
