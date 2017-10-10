module ActiveAdmin
  module ViewHelpers
    module BreadcrumbHelper

      def breadcrumb_links(path = request.path)
        parts = path.split('/').select(&:present?)[0..-2]

        parts.each_with_index.map do |part, index|
          if part =~ /\A(\d+|[a-f0-9]{24})\z/ && parts[index-1]
            parent = active_admin_config.belongs_to_config.try :target
            config = parent && parent.resource_name.route_key == parts[index-1] ? parent : active_admin_config
            name   = display_name config.find_resource part
          end
          name ||= I18n.t "activerecord.models.#{part.singularize}", count: ::ActiveAdmin::Helpers::I18n::PLURAL_MANY_COUNT, default: part.titlecase

          if !config || config.defined_actions.include?(:show)
            link_to name, '/' + parts[0..index].join('/')
          else
            name
          end
        end
      end

    end
  end
end
