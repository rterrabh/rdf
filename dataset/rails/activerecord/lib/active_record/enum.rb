require 'active_support/core_ext/object/deep_dup'

module ActiveRecord
  module Enum
    def self.extended(base) # :nodoc:
      base.class_attribute(:defined_enums)
      base.defined_enums = {}
    end

    def inherited(base) # :nodoc:
      base.defined_enums = defined_enums.deep_dup
      super
    end

    def enum(definitions)
      klass = self
      definitions.each do |name, values|
        enum_values = ActiveSupport::HashWithIndifferentAccess.new
        name        = name.to_sym

        detect_enum_conflict!(name, name.to_s.pluralize, true)
        #nodyna <send-779> <SD COMPLEX (private methods)>
        #nodyna <define_method-780> <DM COMPLEX (events)>
        klass.singleton_class.send(:define_method, name.to_s.pluralize) { enum_values }

        #nodyna <module_eval-781> <ME COMPLEX (define methods)>
        _enum_methods_module.module_eval do
          #nodyna <send-782> <SD EASY (private methods)>
          klass.send(:detect_enum_conflict!, name, "#{name}=")
          #nodyna <define_method-783> <DM COMPLEX (events)>
          define_method("#{name}=") { |value|
            if enum_values.has_key?(value) || value.blank?
              self[name] = enum_values[value]
            elsif enum_values.has_value?(value)
              self[name] = value
            else
              raise ArgumentError, "'#{value}' is not a valid #{name}"
            end
          }

          #nodyna <send-784> <SD EASY (private methods)>
          klass.send(:detect_enum_conflict!, name, name)
          #nodyna <define_method-785> <DM COMPLEX (events)>
          define_method(name) { enum_values.key self[name] }

          #nodyna <send-786> <SD EASY (private methods)>
          klass.send(:detect_enum_conflict!, name, "#{name}_before_type_cast")
          #nodyna <define_method-787> <DM COMPLEX (events)>
          define_method("#{name}_before_type_cast") { enum_values.key self[name] }

          pairs = values.respond_to?(:each_pair) ? values.each_pair : values.each_with_index
          pairs.each do |value, i|
            enum_values[value] = i

            #nodyna <send-788> <SD EASY (private methods)>
            klass.send(:detect_enum_conflict!, name, "#{value}?")
            #nodyna <define_method-789> <DM COMPLEX (events)>
            define_method("#{value}?") { self[name] == i }

            #nodyna <send-790> <SD EASY (private methods)>
            klass.send(:detect_enum_conflict!, name, "#{value}!")
            #nodyna <define_method-791> <DM COMPLEX (events)>
            define_method("#{value}!") { update! name => value }

            #nodyna <send-792> <SD EASY (private methods)>
            klass.send(:detect_enum_conflict!, name, value, true)
            klass.scope value, -> { klass.where name => i }
          end
        end
        defined_enums[name.to_s] = enum_values
      end
    end

    private
      def _enum_methods_module
        @_enum_methods_module ||= begin
          mod = Module.new do
            private
              def save_changed_attribute(attr_name, old)
                if (mapping = self.class.defined_enums[attr_name.to_s])
                  value = _read_attribute(attr_name)
                  if attribute_changed?(attr_name)
                    if mapping[old] == value
                      clear_attribute_changes([attr_name])
                    end
                  else
                    if old != value
                      set_attribute_was(attr_name, mapping.key(old))
                    end
                  end
                else
                  super
                end
              end
          end
          include mod
          mod
        end
      end

      ENUM_CONFLICT_MESSAGE = \
        "You tried to define an enum named \"%{enum}\" on the model \"%{klass}\", but " \
        "this will generate a %{type} method \"%{method}\", which is already defined " \
        "by %{source}."

      def detect_enum_conflict!(enum_name, method_name, klass_method = false)
        if klass_method && dangerous_class_method?(method_name)
          raise ArgumentError, ENUM_CONFLICT_MESSAGE % {
            enum: enum_name,
            klass: self.name,
            type: 'class',
            method: method_name,
            source: 'Active Record'
          }
        elsif !klass_method && dangerous_attribute_method?(method_name)
          raise ArgumentError, ENUM_CONFLICT_MESSAGE % {
            enum: enum_name,
            klass: self.name,
            type: 'instance',
            method: method_name,
            source: 'Active Record'
          }
        elsif !klass_method && method_defined_within?(method_name, _enum_methods_module, Module)
          raise ArgumentError, ENUM_CONFLICT_MESSAGE % {
            enum: enum_name,
            klass: self.name,
            type: 'instance',
            method: method_name,
            source: 'another enum'
          }
        end
      end
  end
end
