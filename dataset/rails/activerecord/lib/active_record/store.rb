require 'active_support/core_ext/hash/indifferent_access'

module ActiveRecord
  module Store
    extend ActiveSupport::Concern

    included do
      class << self
        attr_accessor :local_stored_attributes
      end
    end

    module ClassMethods
      def store(store_attribute, options = {})
        serialize store_attribute, IndifferentCoder.new(options[:coder])
        store_accessor(store_attribute, options[:accessors]) if options.has_key? :accessors
      end

      def store_accessor(store_attribute, *keys)
        keys = keys.flatten

        #nodyna <module_eval-924> <not yet classified>
        _store_accessors_module.module_eval do
          keys.each do |key|
            #nodyna <define_method-925> <DM COMPLEX (array)>
            define_method("#{key}=") do |value|
              write_store_attribute(store_attribute, key, value)
            end

            #nodyna <define_method-926> <DM COMPLEX (array)>
            define_method(key) do
              read_store_attribute(store_attribute, key)
            end
          end
        end

        self.local_stored_attributes ||= {}
        self.local_stored_attributes[store_attribute] ||= []
        self.local_stored_attributes[store_attribute] |= keys
      end

      def _store_accessors_module # :nodoc:
        @_store_accessors_module ||= begin
          mod = Module.new
          include mod
          mod
        end
      end

      def stored_attributes
        parent = superclass.respond_to?(:stored_attributes) ? superclass.stored_attributes : {}
        if self.local_stored_attributes
          parent.merge!(self.local_stored_attributes) { |k, a, b| a | b }
        end
        parent
      end
    end

    protected
      def read_store_attribute(store_attribute, key)
        accessor = store_accessor_for(store_attribute)
        accessor.read(self, store_attribute, key)
      end

      def write_store_attribute(store_attribute, key, value)
        accessor = store_accessor_for(store_attribute)
        accessor.write(self, store_attribute, key, value)
      end

    private
      def store_accessor_for(store_attribute)
        type_for_attribute(store_attribute.to_s).accessor
      end

      class HashAccessor # :nodoc:
        def self.read(object, attribute, key)
          prepare(object, attribute)
          #nodyna <send-927> <SD COMPLEX (change-prone variables)>
          object.public_send(attribute)[key]
        end

        def self.write(object, attribute, key, value)
          prepare(object, attribute)
          if value != read(object, attribute, key)
            #nodyna <send-928> <SD COMPLEX (change-prone variables)>
            object.public_send :"#{attribute}_will_change!"
            #nodyna <send-929> <SD COMPLEX (change-prone variables)>
            object.public_send(attribute)[key] = value
          end
        end

        def self.prepare(object, attribute)
          #nodyna <send-930> <SD COMPLEX (change-prone variables)>
          #nodyna <send-931> <SD COMPLEX (change-prone variables)>
          object.public_send :"#{attribute}=", {} unless object.send(attribute)
        end
      end

      class StringKeyedHashAccessor < HashAccessor # :nodoc:
        def self.read(object, attribute, key)
          super object, attribute, key.to_s
        end

        def self.write(object, attribute, key, value)
          super object, attribute, key.to_s, value
        end
      end

      class IndifferentHashAccessor < ActiveRecord::Store::HashAccessor # :nodoc:
        def self.prepare(object, store_attribute)
          #nodyna <send-932> <SD COMPLEX (change-prone variables)>
          attribute = object.send(store_attribute)
          unless attribute.is_a?(ActiveSupport::HashWithIndifferentAccess)
            attribute = IndifferentCoder.as_indifferent_hash(attribute)
            #nodyna <send-933> <SD COMPLEX (change-prone variables)>
            object.send :"#{store_attribute}=", attribute
          end
          attribute
        end
      end

    class IndifferentCoder # :nodoc:
      def initialize(coder_or_class_name)
        @coder =
          if coder_or_class_name.respond_to?(:load) && coder_or_class_name.respond_to?(:dump)
            coder_or_class_name
          else
            ActiveRecord::Coders::YAMLColumn.new(coder_or_class_name || Object)
          end
      end

      def dump(obj)
        @coder.dump self.class.as_indifferent_hash(obj)
      end

      def load(yaml)
        self.class.as_indifferent_hash(@coder.load(yaml || ''))
      end

      def self.as_indifferent_hash(obj)
        case obj
        when ActiveSupport::HashWithIndifferentAccess
          obj
        when Hash
          obj.with_indifferent_access
        else
          ActiveSupport::HashWithIndifferentAccess.new
        end
      end
    end
  end
end
