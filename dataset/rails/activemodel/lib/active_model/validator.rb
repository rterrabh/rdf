require "active_support/core_ext/module/anonymous"

module ActiveModel

  class Validator
    attr_reader :options

    def self.kind
      @kind ||= name.split('::').last.underscore.sub(/_validator$/, '').to_sym unless anonymous?
    end

    def initialize(options = {})
      @options  = options.except(:class).freeze
    end

    def kind
      self.class.kind
    end

    def validate(record)
      raise NotImplementedError, "Subclasses must implement a validate(record) method."
    end
  end

  class EachValidator < Validator #:nodoc:
    attr_reader :attributes

    def initialize(options)
      @attributes = Array(options.delete(:attributes))
      raise ArgumentError, ":attributes cannot be blank" if @attributes.empty?
      super
      check_validity!
    end

    def validate(record)
      attributes.each do |attribute|
        value = record.read_attribute_for_validation(attribute)
        next if (value.nil? && options[:allow_nil]) || (value.blank? && options[:allow_blank])
        validate_each(record, attribute, value)
      end
    end

    def validate_each(record, attribute, value)
      raise NotImplementedError, "Subclasses must implement a validate_each(record, attribute, value) method"
    end

    def check_validity!
    end
  end

  class BlockValidator < EachValidator #:nodoc:
    def initialize(options, &block)
      @block = block
      super
    end

    private

    def validate_each(record, attribute, value)
      @block.call(record, attribute, value)
    end
  end
end
