require 'active_support/core_ext/module/attribute_accessors'
require 'active_support/core_ext/array/conversions'
require 'active_support/core_ext/hash/conversions'
require 'active_support/core_ext/hash/slice'
require 'active_support/core_ext/time/acts_like'

module ActiveModel
  module Serializers
    module Xml
      extend ActiveSupport::Concern
      include ActiveModel::Serialization

      included do
        extend ActiveModel::Naming
      end

      class Serializer #:nodoc:
        class Attribute #:nodoc:
          attr_reader :name, :value, :type

          def initialize(name, serializable, value)
            @name, @serializable = name, serializable

            if value.acts_like?(:time) && value.respond_to?(:in_time_zone)
              value  = value.in_time_zone
            end

            @value = value
            @type  = compute_type
          end

          def decorations
            decorations = {}
            decorations[:encoding] = 'base64' if type == :binary
            decorations[:type] = (type == :string) ? nil : type
            decorations[:nil] = true if value.nil?
            decorations
          end

        protected

          def compute_type
            return if value.nil?
            type = ActiveSupport::XmlMini::TYPE_NAMES[value.class.name]
            type ||= :string if value.respond_to?(:to_str)
            type ||= :yaml
            type
          end
        end

        class MethodAttribute < Attribute #:nodoc:
        end

        attr_reader :options

        def initialize(serializable, options = nil)
          @serializable = serializable
          @options = options ? options.dup : {}
        end

        def serializable_hash
          @serializable.serializable_hash(@options.except(:include))
        end

        def serializable_collection
          methods = Array(options[:methods]).map(&:to_s)
          serializable_hash.map do |name, value|
            name = name.to_s
            if methods.include?(name)
              self.class::MethodAttribute.new(name, @serializable, value)
            else
              self.class::Attribute.new(name, @serializable, value)
            end
          end
        end

        def serialize
          require 'builder' unless defined? ::Builder

          options[:indent]  ||= 2
          options[:builder] ||= ::Builder::XmlMarkup.new(indent: options[:indent])

          @builder = options[:builder]
          @builder.instruct! unless options[:skip_instruct]

          root = (options[:root] || @serializable.model_name.element).to_s
          root = ActiveSupport::XmlMini.rename_key(root, options)

          args = [root]
          args << { xmlns: options[:namespace] } if options[:namespace]
          args << { type: options[:type] } if options[:type] && !options[:skip_types]

          @builder.tag!(*args) do
            add_attributes_and_methods
            add_includes
            add_extra_behavior
            add_procs
            yield @builder if block_given?
          end
        end

      private

        def add_extra_behavior
        end

        def add_attributes_and_methods
          serializable_collection.each do |attribute|
            key = ActiveSupport::XmlMini.rename_key(attribute.name, options)
            ActiveSupport::XmlMini.to_tag(key, attribute.value,
              options.merge(attribute.decorations))
          end
        end

        def add_includes
          #nodyna <send-975> <SD EASY (private methods)>
          @serializable.send(:serializable_add_includes, options) do |association, records, opts|
            add_associations(association, records, opts)
          end
        end

        def add_associations(association, records, opts)
          merged_options = opts.merge(options.slice(:builder, :indent))
          merged_options[:skip_instruct] = true

          [:skip_types, :dasherize, :camelize].each do |key|
            merged_options[key] = options[key] if merged_options[key].nil? && !options[key].nil?
          end

          if records.respond_to?(:to_ary)
            records = records.to_ary

            tag  = ActiveSupport::XmlMini.rename_key(association.to_s, options)
            type = options[:skip_types] ? { } : { type: "array" }
            association_name = association.to_s.singularize
            merged_options[:root] = association_name

            if records.empty?
              @builder.tag!(tag, type)
            else
              @builder.tag!(tag, type) do
                records.each do |record|
                  if options[:skip_types]
                    record_type = {}
                  else
                    record_class = (record.class.to_s.underscore == association_name) ? nil : record.class.name
                    record_type = { type: record_class }
                  end

                  record.to_xml merged_options.merge(record_type)
                end
              end
            end
          else
            merged_options[:root] = association.to_s

            unless records.class.to_s.underscore == association.to_s
              merged_options[:type] = records.class.name
            end

            records.to_xml merged_options
          end
        end

        def add_procs
          if procs = options.delete(:procs)
            Array(procs).each do |proc|
              if proc.arity == 1
                proc.call(options)
              else
                proc.call(options, @serializable)
              end
            end
          end
        end
      end

      def to_xml(options = {}, &block)
        Serializer.new(self, options).serialize(&block)
      end

      def from_xml(xml)
        self.attributes = Hash.from_xml(xml).values.first
        self
      end
    end
  end
end
