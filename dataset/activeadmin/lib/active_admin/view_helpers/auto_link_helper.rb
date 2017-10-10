module ActiveAdmin
  module ViewHelpers
    module AutoLinkHelper

      def auto_link(resource, content = display_name(resource))
        if url = auto_url_for(resource)
          link_to content, url
        else
          content
        end
      end

      def auto_url_for(resource)
        config = active_admin_resource_for(resource.class)
        return unless config

        if config.controller.action_methods.include?("show") &&
          authorized?(ActiveAdmin::Auth::READ, resource)
          url_for config.route_instance_path resource
        elsif config.controller.action_methods.include?("edit") &&
          authorized?(ActiveAdmin::Auth::UPDATE, resource)
          url_for config.route_edit_instance_path resource
        end
      end

      def active_admin_resource_for(klass)
        if respond_to? :active_admin_namespace
          active_admin_namespace.resource_for klass
        end
      end

    end
  end
end
