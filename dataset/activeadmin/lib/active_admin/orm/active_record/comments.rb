require 'active_admin/orm/active_record/comments/views'
require 'active_admin/orm/active_record/comments/show_page_helper'
require 'active_admin/orm/active_record/comments/namespace_helper'
require 'active_admin/orm/active_record/comments/resource_helper'

ActiveAdmin::Application.inheritable_setting :comments,                   true
ActiveAdmin::Application.inheritable_setting :show_comments_in_menu,      true
ActiveAdmin::Application.inheritable_setting :comments_registration_name, 'Comment'

#nodyna <send-2> <SD TRIVIAL (public methods)>
ActiveAdmin::Namespace.send :include, ActiveAdmin::Comments::NamespaceHelper
#nodyna <send-3> <SD TRIVIAL (public methods)>
ActiveAdmin::Resource.send  :include, ActiveAdmin::Comments::ResourceHelper
#nodyna <send-4> <SD TRIVIAL (public methods)>
ActiveAdmin.application.view_factory.show_page.send :include, ActiveAdmin::Comments::ShowPageHelper

ActiveAdmin.autoload :Comment, 'active_admin/orm/active_record/comments/comment'

ActiveAdmin.after_load do |app|
  app.namespaces.each do |namespace|
    namespace.register ActiveAdmin::Comment, as: namespace.comments_registration_name do
      actions :index, :show, :create

      menu false unless namespace.comments && namespace.show_comments_in_menu

      config.comments      = false # Don't allow comments on comments
      config.batch_actions = false # The default destroy batch action isn't showing up anyway...

      scope :all, show_count: false
      app.namespaces.map(&:name).each do |name|
        scope name, default: namespace.name == name do |scope|
          scope.where namespace: name.to_s
        end
      end
 	
      before_save do |comment|
        comment.namespace = active_admin_config.namespace.name
        comment.author    = current_active_admin_user
      end

      controller do
        def scoped_collection
          super.includes *( # rails/rails#14734
            ActiveAdmin::Dependency.rails?('>= 4.1.0', '<= 4.1.1') ?
              [:author] : [:author, :resource]
          )
        end

        def create
          create! do |success, failure|
            success.html{ redirect_to :back }
            failure.html do
              flash[:error] = I18n.t 'active_admin.comments.errors.empty_text'
              redirect_to :back
            end
          end
        end
      end

      unless Rails::VERSION::MAJOR == 3 && !defined? StrongParameters
        permit_params :body, :namespace, :resource_id, :resource_type
      end

      index do
        column I18n.t('active_admin.comments.resource_type'), :resource_type
        column I18n.t('active_admin.comments.author_type'),   :author_type
        column I18n.t('active_admin.comments.resource'),      :resource
        column I18n.t('active_admin.comments.author'),        :author
        column I18n.t('active_admin.comments.body'),          :body
        actions
      end
    end
  end
end
