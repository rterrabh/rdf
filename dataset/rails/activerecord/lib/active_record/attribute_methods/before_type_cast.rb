module ActiveRecord
  module AttributeMethods
    module BeforeTypeCast
      extend ActiveSupport::Concern

      included do
        attribute_method_suffix "_before_type_cast"
        attribute_method_suffix "_came_from_user?"
      end

      def read_attribute_before_type_cast(attr_name)
        @attributes[attr_name.to_s].value_before_type_cast
      end

      def attributes_before_type_cast
        @attributes.values_before_type_cast
      end

      private

      def attribute_before_type_cast(attribute_name)
        read_attribute_before_type_cast(attribute_name)
      end

      def attribute_came_from_user?(attribute_name)
        @attributes[attribute_name].came_from_user?
      end
    end
  end
end
