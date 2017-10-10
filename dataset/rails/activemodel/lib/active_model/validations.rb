require 'active_support/core_ext/array/extract_options'
require 'active_support/core_ext/hash/keys'
require 'active_support/core_ext/hash/except'

module ActiveModel

  module Validations
    extend ActiveSupport::Concern

    included do
      extend ActiveModel::Naming
      extend ActiveModel::Callbacks
      extend ActiveModel::Translation

      extend  HelperMethods
      include HelperMethods

      attr_accessor :validation_context
      define_callbacks :validate, scope: :name

      class_attribute :_validators
      self._validators = Hash.new { |h,k| h[k] = [] }
    end

    module ClassMethods
      def validates_each(*attr_names, &block)
        validates_with BlockValidator, _merge_attributes(attr_names), &block
      end

      VALID_OPTIONS_FOR_VALIDATE = [:on, :if, :unless, :prepend].freeze # :nodoc:

      def validate(*args, &block)
        options = args.extract_options!

        if args.all? { |arg| arg.is_a?(Symbol) }
          options.each_key do |k|
            unless VALID_OPTIONS_FOR_VALIDATE.include?(k)
              raise ArgumentError.new("Unknown key: #{k.inspect}. Valid keys are: #{VALID_OPTIONS_FOR_VALIDATE.map(&:inspect).join(', ')}. Perhaps you meant to call `validates` instead of `validate`?")
            end
          end
        end

        if options.key?(:on)
          options = options.dup
          options[:if] = Array(options[:if])
          options[:if].unshift ->(o) {
            Array(options[:on]).include?(o.validation_context)
          }
        end

        args << options
        set_callback(:validate, *args, &block)
      end

      def validators
        _validators.values.flatten.uniq
      end

      def clear_validators!
        reset_callbacks(:validate)
        _validators.clear
      end

      def validators_on(*attributes)
        attributes.flat_map do |attribute|
          _validators[attribute.to_sym]
        end
      end

      def attribute_method?(attribute)
        method_defined?(attribute)
      end

      def inherited(base) #:nodoc:
        dup = _validators.dup
        base._validators = dup.each { |k, v| dup[k] = v.dup }
        super
      end
    end

    def initialize_dup(other) #:nodoc:
      @errors = nil
      super
    end

    def errors
      @errors ||= Errors.new(self)
    end

    def valid?(context = nil)
      current_context, self.validation_context = validation_context, context
      errors.clear
      run_validations!
    ensure
      self.validation_context = current_context
    end

    alias_method :validate, :valid?

    def invalid?(context = nil)
      !valid?(context)
    end

    #nodyna <send-960> <not yet classified>
    alias :read_attribute_for_validation :send

  protected

    def run_validations! #:nodoc:
      _run_validate_callbacks
      errors.empty?
    end
  end
end

Dir[File.dirname(__FILE__) + "/validations/*.rb"].each { |file| require file }
