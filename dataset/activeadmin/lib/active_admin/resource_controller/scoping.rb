module ActiveAdmin
  class ResourceController < BaseController

    module Scoping
      extend ActiveSupport::Concern

      protected

      def begin_of_association_chain
        return nil unless active_admin_config.scope_to?(self)
        render_in_context(self, active_admin_config.scope_to_method)
      end

      def method_for_association_chain
        active_admin_config.scope_to_association_method || super
      end

    end
  end
end
