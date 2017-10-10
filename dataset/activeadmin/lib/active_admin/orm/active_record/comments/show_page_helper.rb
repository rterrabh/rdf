module ActiveAdmin
  module Comments

    module ShowPageHelper

      def default_main_content
        super
        active_admin_comments if active_admin_config.comments?
      end

      def active_admin_comments(*args, &block)
        active_admin_comments_for(resource, *args, &block)
      end
    end

  end
end
