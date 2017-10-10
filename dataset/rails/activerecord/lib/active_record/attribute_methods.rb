require 'active_support/core_ext/enumerable'
require 'active_support/core_ext/string/filters'
require 'mutex_m'
require 'thread_safe'

module ActiveRecord
  module AttributeMethods
    extend ActiveSupport::Concern
    include ActiveModel::AttributeMethods

    included do
      initialize_generated_modules
      include Read
      include Write
      include BeforeTypeCast
      include Query
      include PrimaryKey
      include TimeZoneConversion
      include Dirty
      include Serialization

      delegate :column_for_attribute, to: :class
    end

    AttrNames = Module.new {
      def self.set_name_cache(name, value)
        const_name = "ATTR_#{name}"
        unless const_defined? const_name
          #nodyna <const_set-854> <CS COMPLEX (change-prone variable)>
          const_set const_name, value.dup.freeze
        end
      end
    }

    BLACKLISTED_CLASS_METHODS = %w(private public protected allocate new name parent superclass)

    class AttributeMethodCache
      def initialize
        @module = Module.new
        @method_cache = ThreadSafe::Cache.new
      end

      def [](name)
        @method_cache.compute_if_absent(name) do
          safe_name = name.unpack('h*').first
          temp_method = "__temp__#{safe_name}"
          ActiveRecord::AttributeMethods::AttrNames.set_name_cache safe_name, name
          #nodyna <module_eval-855> <not yet classified>
          @module.module_eval method_body(temp_method, safe_name), __FILE__, __LINE__
          @module.instance_method temp_method
        end
      end

      private

      def method_body(method_name, const_name)
        raise NotImplementedError, "Subclasses must implement a method_body(method_name, const_name) method."
      end
    end

    class GeneratedAttributeMethods < Module; end # :nodoc:

    module ClassMethods
      def inherited(child_class) #:nodoc:
        child_class.initialize_generated_modules
        super
      end

      def initialize_generated_modules # :nodoc:
        @generated_attribute_methods = GeneratedAttributeMethods.new { extend Mutex_m }
        @attribute_methods_generated = false
        include @generated_attribute_methods

        super
      end

      def define_attribute_methods # :nodoc:
        return false if @attribute_methods_generated
        generated_attribute_methods.synchronize do
          return false if @attribute_methods_generated
          superclass.define_attribute_methods unless self == base_class
          super(column_names)
          @attribute_methods_generated = true
        end
        true
      end

      def undefine_attribute_methods # :nodoc:
        generated_attribute_methods.synchronize do
          super if defined?(@attribute_methods_generated) && @attribute_methods_generated
          @attribute_methods_generated = false
        end
      end

      def instance_method_already_implemented?(method_name)
        if dangerous_attribute_method?(method_name)
          raise DangerousAttributeError, "#{method_name} is defined by Active Record. Check to make sure that you don't have an attribute or method with the same name."
        end

        if superclass == Base
          super
        else
          defined = method_defined_within?(method_name, superclass, Base) &&
            ! superclass.instance_method(method_name).owner.is_a?(GeneratedAttributeMethods)
          defined || super
        end
      end

      def dangerous_attribute_method?(name) # :nodoc:
        method_defined_within?(name, Base)
      end

      def method_defined_within?(name, klass, superklass = klass.superclass) # :nodoc:
        if klass.method_defined?(name) || klass.private_method_defined?(name)
          if superklass.method_defined?(name) || superklass.private_method_defined?(name)
            klass.instance_method(name).owner != superklass.instance_method(name).owner
          else
            true
          end
        else
          false
        end
      end

      def dangerous_class_method?(method_name)
        BLACKLISTED_CLASS_METHODS.include?(method_name.to_s) || class_method_defined_within?(method_name, Base)
      end

      def class_method_defined_within?(name, klass, superklass = klass.superclass) # :nodoc
        if klass.respond_to?(name, true)
          if superklass.respond_to?(name, true)
            klass.method(name).owner != superklass.method(name).owner
          else
            true
          end
        else
          false
        end
      end

      def attribute_method?(attribute)
        super || (table_exists? && column_names.include?(attribute.to_s.sub(/=$/, '')))
      end

      def attribute_names
        @attribute_names ||= if !abstract_class? && table_exists?
            column_names
          else
            []
          end
      end

      def column_for_attribute(name)
        column = columns_hash[name.to_s]
        if column.nil?
          ActiveSupport::Deprecation.warn(<<-MSG.squish)
            `#column_for_attribute` will return a null object for non-existent
            columns in Rails 5. Use `#has_attribute?` if you need to check for
            an attribute's existence.
          MSG
        end
        column
      end
    end

    def respond_to?(name, include_private = false)
      return false unless super
      name = name.to_s

      if defined?(@attributes) && self.class.column_names.include?(name)
        return has_attribute?(name)
      end

      return true
    end

    def has_attribute?(attr_name)
      @attributes.key?(attr_name.to_s)
    end

    def attribute_names
      @attributes.keys
    end

    def attributes
      @attributes.to_hash
    end

    def attribute_for_inspect(attr_name)
      value = read_attribute(attr_name)

      if value.is_a?(String) && value.length > 50
        "#{value[0, 50]}...".inspect
      elsif value.is_a?(Date) || value.is_a?(Time)
        %("#{value.to_s(:db)}")
      elsif value.is_a?(Array) && value.size > 10
        inspected = value.first(10).inspect
        %(#{inspected[0...-1]}, ...])
      else
        value.inspect
      end
    end

    def attribute_present?(attribute)
      value = _read_attribute(attribute)
      !value.nil? && !(value.respond_to?(:empty?) && value.empty?)
    end

    def [](attr_name)
      read_attribute(attr_name) { |n| missing_attribute(n, caller) }
    end

    def []=(attr_name, value)
      write_attribute(attr_name, value)
    end

    protected

    def clone_attribute_value(reader_method, attribute_name) # :nodoc:
      #nodyna <send-856> <SD COMPLEX (change-prone variables)>
      value = send(reader_method, attribute_name)
      value.duplicable? ? value.clone : value
    rescue TypeError, NoMethodError
      value
    end

    def arel_attributes_with_values_for_create(attribute_names) # :nodoc:
      arel_attributes_with_values(attributes_for_create(attribute_names))
    end

    def arel_attributes_with_values_for_update(attribute_names) # :nodoc:
      arel_attributes_with_values(attributes_for_update(attribute_names))
    end

    def attribute_method?(attr_name) # :nodoc:
      defined?(@attributes) && @attributes.key?(attr_name)
    end

    private

    def arel_attributes_with_values(attribute_names)
      attrs = {}
      arel_table = self.class.arel_table

      attribute_names.each do |name|
        attrs[arel_table[name]] = typecasted_attribute_value(name)
      end
      attrs
    end

    def attributes_for_update(attribute_names)
      attribute_names.reject do |name|
        readonly_attribute?(name)
      end
    end

    def attributes_for_create(attribute_names)
      attribute_names.reject do |name|
        pk_attribute?(name) && id.nil?
      end
    end

    def readonly_attribute?(name)
      self.class.readonly_attributes.include?(name)
    end

    def pk_attribute?(name)
      name == self.class.primary_key
    end

    def typecasted_attribute_value(name)
      _read_attribute(name)
    end
  end
end
