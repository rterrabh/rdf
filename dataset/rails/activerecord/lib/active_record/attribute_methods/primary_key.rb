require 'set'

module ActiveRecord
  module AttributeMethods
    module PrimaryKey
      extend ActiveSupport::Concern

      def to_key
        sync_with_transaction_state
        key = self.id
        [key] if key
      end

      def id
        if pk = self.class.primary_key
          sync_with_transaction_state
          _read_attribute(pk)
        end
      end

      def id=(value)
        sync_with_transaction_state
        write_attribute(self.class.primary_key, value) if self.class.primary_key
      end

      def id?
        sync_with_transaction_state
        query_attribute(self.class.primary_key)
      end

      def id_before_type_cast
        sync_with_transaction_state
        read_attribute_before_type_cast(self.class.primary_key)
      end

      def id_was
        sync_with_transaction_state
        attribute_was(self.class.primary_key)
      end

      protected

      def attribute_method?(attr_name)
        attr_name == 'id' || super
      end

      module ClassMethods
        def define_method_attribute(attr_name)
          super

          if attr_name == primary_key && attr_name != 'id'
            #nodyna <send-765> <SD COMPLEX (private methods)>
            generated_attribute_methods.send(:alias_method, :id, primary_key)
          end
        end

        ID_ATTRIBUTE_METHODS = %w(id id= id? id_before_type_cast id_was).to_set

        def dangerous_attribute_method?(method_name)
          super && !ID_ATTRIBUTE_METHODS.include?(method_name)
        end

        def primary_key
          @primary_key = reset_primary_key unless defined? @primary_key
          @primary_key
        end

        def quoted_primary_key
          @quoted_primary_key ||= connection.quote_column_name(primary_key)
        end

        def reset_primary_key #:nodoc:
          if self == base_class
            self.primary_key = get_primary_key(base_class.name)
          else
            self.primary_key = base_class.primary_key
          end
        end

        def get_primary_key(base_name) #:nodoc:
          if base_name && primary_key_prefix_type == :table_name
            base_name.foreign_key(false)
          elsif base_name && primary_key_prefix_type == :table_name_with_underscore
            base_name.foreign_key
          else
            if ActiveRecord::Base != self && table_exists?
              connection.schema_cache.primary_keys(table_name)
            else
              'id'
            end
          end
        end

        def primary_key=(value)
          @primary_key        = value && value.to_s
          @quoted_primary_key = nil
          @attributes_builder = nil
        end
      end
    end
  end
end
