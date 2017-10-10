require 'active_support/core_ext/module/method_transplanting'

module ActiveRecord
  module AttributeMethods
    module Read
      ReaderMethodCache = Class.new(AttributeMethodCache) {
        private
        def method_body(method_name, const_name)
          <<-EOMETHOD
          def #{method_name}
            name = ::ActiveRecord::AttributeMethods::AttrNames::ATTR_#{const_name}
            _read_attribute(name) { |n| missing_attribute(n, caller) }
          end
          EOMETHOD
        end
      }.new

      extend ActiveSupport::Concern

      module ClassMethods
        [:cache_attributes, :cached_attributes, :cache_attribute?].each do |method_name|
          #nodyna <define_method-757> <DM MODERATE (array)>
          define_method method_name do |*|
            cached_attributes_deprecation_warning(method_name)
            true
          end
        end

        protected

        def cached_attributes_deprecation_warning(method_name)
          ActiveSupport::Deprecation.warn "Calling `#{method_name}` is no longer necessary. All attributes are cached."
        end

        if Module.methods_transplantable?
          def define_method_attribute(name)
            method = ReaderMethodCache[name]
            #nodyna <define_method-758> <DM COMPLEX (events)>
            #nodyna <module_eval-759> <not yet classified>
            generated_attribute_methods.module_eval { define_method name, method }
          end
        else
          def define_method_attribute(name)
            safe_name = name.unpack('h*').first
            temp_method = "__temp__#{safe_name}"

            ActiveRecord::AttributeMethods::AttrNames.set_name_cache safe_name, name

            #nodyna <module_eval-760> <not yet classified>
            generated_attribute_methods.module_eval <<-STR, __FILE__, __LINE__ + 1
              def #{temp_method}
                name = ::ActiveRecord::AttributeMethods::AttrNames::ATTR_#{safe_name}
                _read_attribute(name) { |n| missing_attribute(n, caller) }
              end
            STR

            #nodyna <module_eval-761> <not yet classified>
            generated_attribute_methods.module_eval do
              alias_method name, temp_method
              undef_method temp_method
            end
          end
        end
      end

      ID = 'id'.freeze

      def read_attribute(attr_name, &block)
        name = attr_name.to_s
        name = self.class.primary_key if name == ID
        _read_attribute(name, &block)
      end

      def _read_attribute(attr_name) # :nodoc:
        @attributes.fetch_value(attr_name.to_s) { |n| yield n if block_given? }
      end

      private

      def attribute(attribute_name)
        _read_attribute(attribute_name)
      end
    end
  end
end
