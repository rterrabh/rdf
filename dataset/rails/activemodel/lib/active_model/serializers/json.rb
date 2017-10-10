require 'active_support/json'

module ActiveModel
  module Serializers
    module JSON
      extend ActiveSupport::Concern
      include ActiveModel::Serialization

      included do
        extend ActiveModel::Naming

        class_attribute :include_root_in_json
        self.include_root_in_json = false
      end

      def as_json(options = nil)
        root = if options && options.key?(:root)
          options[:root]
        else
          include_root_in_json
        end

        if root
          root = model_name.element if root == true
          { root => serializable_hash(options) }
        else
          serializable_hash(options)
        end
      end

      def from_json(json, include_root=include_root_in_json)
        hash = ActiveSupport::JSON.decode(json)
        hash = hash.values.first if include_root
        self.attributes = hash
        self
      end
    end
  end
end
