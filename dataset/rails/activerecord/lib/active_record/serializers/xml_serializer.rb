require 'active_support/core_ext/hash/conversions'

module ActiveRecord #:nodoc:
  module Serialization
    include ActiveModel::Serializers::Xml

    def to_xml(options = {}, &block)
      XmlSerializer.new(self, options).serialize(&block)
    end
  end

  class XmlSerializer < ActiveModel::Serializers::Xml::Serializer #:nodoc:
    class Attribute < ActiveModel::Serializers::Xml::Serializer::Attribute #:nodoc:
      def compute_type
        klass = @serializable.class
        column = klass.columns_hash[name] || Type::Value.new

        type = ActiveSupport::XmlMini::TYPE_NAMES[value.class.name] || column.type

        { :text => :string,
          :time => :datetime }[type] || type
      end
      protected :compute_type
    end
  end
end
