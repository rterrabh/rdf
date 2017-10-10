require 'active_support/core_ext/module/attribute_accessors'


module ActiveRecord::Associations::Builder
  class Association #:nodoc:
    class << self
      attr_accessor :extensions
      attr_accessor :valid_options
    end
    self.extensions = []

    self.valid_options = [:class_name, :anonymous_class, :foreign_key, :validate]

    attr_reader :name, :scope, :options

    def self.build(model, name, scope, options, &block)
      if model.dangerous_attribute_method?(name)
        raise ArgumentError, "You tried to define an association named #{name} on the model #{model.name}, but " \
                             "this will conflict with a method #{name} already defined by Active Record. " \
                             "Please choose a different association name."
      end

      builder = create_builder model, name, scope, options, &block
      reflection = builder.build(model)
      define_accessors model, reflection
      define_callbacks model, reflection
      define_validations model, reflection
      builder.define_extensions model
      reflection
    end

    def self.create_builder(model, name, scope, options, &block)
      raise ArgumentError, "association names must be a Symbol" unless name.kind_of?(Symbol)

      new(model, name, scope, options, &block)
    end

    def initialize(model, name, scope, options)
      if scope.is_a?(Hash)
        options = scope
        scope   = nil
      end

      @name    = name
      @scope   = scope
      @options = options

      validate_options

      if scope && scope.arity == 0
        #nodyna <instance_exec-893> <IEX COMPLEX (block without parameters)>
        @scope = proc { instance_exec(&scope) }
      end
    end

    def build(model)
      ActiveRecord::Reflection.create(macro, name, scope, options, model)
    end

    def macro
      raise NotImplementedError
    end

    def valid_options
      Association.valid_options + Association.extensions.flat_map(&:valid_options)
    end

    def validate_options
      options.assert_valid_keys(valid_options)
    end

    def define_extensions(model)
    end

    def self.define_callbacks(model, reflection)
      if dependent = reflection.options[:dependent]
        check_dependent_options(dependent)
        add_destroy_callbacks(model, reflection)
      end

      Association.extensions.each do |extension|
        extension.build model, reflection
      end
    end

    def self.define_accessors(model, reflection)
      mixin = model.generated_association_methods
      name = reflection.name
      define_readers(mixin, name)
      define_writers(mixin, name)
    end

    def self.define_readers(mixin, name)
      #nodyna <class_eval-894> <not yet classified>
      mixin.class_eval <<-CODE, __FILE__, __LINE__ + 1
        def #{name}(*args)
          association(:#{name}).reader(*args)
        end
      CODE
    end

    def self.define_writers(mixin, name)
      #nodyna <class_eval-895> <not yet classified>
      mixin.class_eval <<-CODE, __FILE__, __LINE__ + 1
        def #{name}=(value)
          association(:#{name}).writer(value)
        end
      CODE
    end

    def self.define_validations(model, reflection)
    end

    def self.valid_dependent_options
      raise NotImplementedError
    end

    private

    def self.check_dependent_options(dependent)
      unless valid_dependent_options.include? dependent
        raise ArgumentError, "The :dependent option must be one of #{valid_dependent_options}, but is :#{dependent}"
      end
    end

    def self.add_destroy_callbacks(model, reflection)
      name = reflection.name
      model.before_destroy lambda { |o| o.association(name).handle_dependency }
    end
  end
end
