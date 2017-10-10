require 'active_support/per_thread_registry'

module ActiveRecord
  module Scoping
    extend ActiveSupport::Concern

    included do
      include Default
      include Named
    end

    module ClassMethods
      def current_scope #:nodoc:
        ScopeRegistry.value_for(:current_scope, base_class.to_s)
      end

      def current_scope=(scope) #:nodoc:
        ScopeRegistry.set_value_for(:current_scope, base_class.to_s, scope)
      end
    end

    def populate_with_current_scope_attributes
      return unless self.class.scope_attributes?

      self.class.scope_attributes.each do |att,value|
        #nodyna <send-859> <SD COMPLEX (array)>
        send("#{att}=", value) if respond_to?("#{att}=")
      end
    end

    def initialize_internals_callback
      super
      populate_with_current_scope_attributes
    end

    class ScopeRegistry # :nodoc:
      extend ActiveSupport::PerThreadRegistry

      VALID_SCOPE_TYPES = [:current_scope, :ignore_default_scope]

      def initialize
        @registry = Hash.new { |hash, key| hash[key] = {} }
      end

      def value_for(scope_type, variable_name)
        raise_invalid_scope_type!(scope_type)
        @registry[scope_type][variable_name]
      end

      def set_value_for(scope_type, variable_name, value)
        raise_invalid_scope_type!(scope_type)
        @registry[scope_type][variable_name] = value
      end

      private

      def raise_invalid_scope_type!(scope_type)
        if !VALID_SCOPE_TYPES.include?(scope_type)
          raise ArgumentError, "Invalid scope type '#{scope_type}' sent to the registry. Scope types must be included in VALID_SCOPE_TYPES"
        end
      end
    end
  end
end
