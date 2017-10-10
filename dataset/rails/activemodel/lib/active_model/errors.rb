
require 'active_support/core_ext/array/conversions'
require 'active_support/core_ext/string/inflections'

module ActiveModel
  class Errors
    include Enumerable

    CALLBACKS_OPTIONS = [:if, :unless, :on, :allow_nil, :allow_blank, :strict]

    attr_reader :messages

    def initialize(base)
      @base     = base
      @messages = {}
    end

    def initialize_dup(other) # :nodoc:
      @messages = other.messages.dup
      super
    end

    def clear
      messages.clear
    end

    def include?(attribute)
      messages[attribute].present?
    end
    alias :has_key? :include?
    alias :key? :include?

    def get(key)
      messages[key]
    end

    def set(key, value)
      messages[key] = value
    end

    def delete(key)
      messages.delete(key)
    end

    def [](attribute)
      get(attribute.to_sym) || set(attribute.to_sym, [])
    end

    def []=(attribute, error)
      self[attribute] << error
    end

    def each
      messages.each_key do |attribute|
        self[attribute].each { |error| yield attribute, error }
      end
    end

    def size
      values.flatten.size
    end

    def values
      messages.values
    end

    def keys
      messages.keys
    end

    def to_a
      full_messages
    end

    def count
      to_a.size
    end

    def empty?
      all? { |k, v| v && v.empty? && !v.is_a?(String) }
    end
    alias_method :blank?, :empty?

    def to_xml(options={})
      to_a.to_xml({ root: "errors", skip_types: true }.merge!(options))
    end

    def as_json(options=nil)
      to_hash(options && options[:full_messages])
    end

    def to_hash(full_messages = false)
      if full_messages
        self.messages.each_with_object({}) do |(attribute, array), messages|
          messages[attribute] = array.map { |message| full_message(attribute, message) }
        end
      else
        self.messages.dup
      end
    end

    def add(attribute, message = :invalid, options = {})
      message = normalize_message(attribute, message, options)
      if exception = options[:strict]
        exception = ActiveModel::StrictValidationFailed if exception == true
        raise exception, full_message(attribute, message)
      end

      self[attribute] << message
    end

    def add_on_empty(attributes, options = {})
      Array(attributes).each do |attribute|
        #nodyna <send-961> <SD TRIVIAL (public methods)>
        value = @base.send(:read_attribute_for_validation, attribute)
        is_empty = value.respond_to?(:empty?) ? value.empty? : false
        add(attribute, :empty, options) if value.nil? || is_empty
      end
    end

    def add_on_blank(attributes, options = {})
      Array(attributes).each do |attribute|
        #nodyna <send-962> <SD TRIVIAL (public methods)>
        value = @base.send(:read_attribute_for_validation, attribute)
        add(attribute, :blank, options) if value.blank?
      end
    end

    def added?(attribute, message = :invalid, options = {})
      message = normalize_message(attribute, message, options)
      self[attribute].include? message
    end

    def full_messages
      map { |attribute, message| full_message(attribute, message) }
    end

    def full_messages_for(attribute)
      (get(attribute) || []).map { |message| full_message(attribute, message) }
    end

    def full_message(attribute, message)
      return message if attribute == :base
      attr_name = attribute.to_s.tr('.', '_').humanize
      attr_name = @base.class.human_attribute_name(attribute, default: attr_name)
      I18n.t(:"errors.format", {
        default:  "%{attribute} %{message}",
        attribute: attr_name,
        message:   message
      })
    end

    def generate_message(attribute, type = :invalid, options = {})
      type = options.delete(:message) if options[:message].is_a?(Symbol)

      if @base.class.respond_to?(:i18n_scope)
        defaults = @base.class.lookup_ancestors.map do |klass|
          [ :"#{@base.class.i18n_scope}.errors.models.#{klass.model_name.i18n_key}.attributes.#{attribute}.#{type}",
            :"#{@base.class.i18n_scope}.errors.models.#{klass.model_name.i18n_key}.#{type}" ]
        end
      else
        defaults = []
      end

      defaults << options.delete(:message)
      defaults << :"#{@base.class.i18n_scope}.errors.messages.#{type}" if @base.class.respond_to?(:i18n_scope)
      defaults << :"errors.attributes.#{attribute}.#{type}"
      defaults << :"errors.messages.#{type}"

      defaults.compact!
      defaults.flatten!

      key = defaults.shift
      #nodyna <send-963> <SD TRIVIAL (public methods)>
      value = (attribute != :base ? @base.send(:read_attribute_for_validation, attribute) : nil)

      options = {
        default: defaults,
        model: @base.model_name.human,
        attribute: @base.class.human_attribute_name(attribute),
        value: value
      }.merge!(options)

      I18n.translate(key, options)
    end

  private
    def normalize_message(attribute, message, options)
      case message
      when Symbol
        generate_message(attribute, message, options.except(*CALLBACKS_OPTIONS))
      when Proc
        message.call
      else
        message
      end
    end
  end

  class StrictValidationFailed < StandardError
  end
end
