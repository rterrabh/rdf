require 'rails_admin/config/proxyable'
require 'rails_admin/config/configurable'
require 'rails_admin/config/hideable'

module RailsAdmin
  module Config
    module Actions
      class Base
        include RailsAdmin::Config::Proxyable
        include RailsAdmin::Config::Configurable
        include RailsAdmin::Config::Hideable

        register_instance_option :only do
          nil
        end

        register_instance_option :except do
          []
        end

        register_instance_option :link_icon do
          'icon-question-sign'
        end

        register_instance_option :visible? do
          authorized?
        end

        register_instance_option :enabled? do
          bindings[:abstract_model].nil? || (
            (only.nil? || [only].flatten.collect(&:to_s).include?(bindings[:abstract_model].to_s)) &&
            ![except].flatten.collect(&:to_s).include?(bindings[:abstract_model].to_s) &&
            !bindings[:abstract_model].config.excluded?
          )
        end

        register_instance_option :authorized? do
          enabled? && (
            bindings[:controller].try(:authorization_adapter).nil? || bindings[:controller].authorization_adapter.authorized?(authorization_key, bindings[:abstract_model], bindings[:object])
          )
        end

        register_instance_option :root? do
          false
        end

        register_instance_option :collection? do
          false
        end

        register_instance_option :member? do
          false
        end

        register_instance_option :pjax? do
          true
        end

        register_instance_option :controller do
          proc do
            render action: @action.template_name
          end
        end

        register_instance_option :bulkable? do
          false
        end

        register_instance_option :template_name do
          key.to_sym
        end

        register_instance_option :authorization_key do
          key.to_sym
        end

        register_instance_option :http_methods do
          [:get]
        end

        register_instance_option :route_fragment do
          custom_key.to_s
        end

        register_instance_option :action_name do
          custom_key.to_sym
        end

        register_instance_option :i18n_key do
          key
        end

        register_instance_option :custom_key do
          key
        end

        register_instance_option :breadcrumb_parent do
          case
          when root?
            [:dashboard]
          when collection?
            [:index, bindings[:abstract_model]]
          when member?
            [:show, bindings[:abstract_model], bindings[:object]]
          end
        end


        def key
          self.class.key
        end

        def self.key
          name.to_s.demodulize.underscore.to_sym
        end
      end
    end
  end
end
