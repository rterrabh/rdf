require 'active_admin/base_controller/authorization'
require 'active_admin/base_controller/menu'

module ActiveAdmin
  class BaseController < ::InheritedResources::Base
    helper ::ActiveAdmin::ViewHelpers
    helper_method :env

    layout :determine_active_admin_layout

    before_filter :only_render_implemented_actions
    before_filter :authenticate_active_admin_user

    class << self
      public :actions

      attr_accessor :active_admin_config
    end

    def only_render_implemented_actions
      raise AbstractController::ActionNotFound unless action_methods.include?(params[:action])
    end

    include Menu
    include Authorization

    private

    def authenticate_active_admin_user
      #nodyna <send-114> <SD COMPLEX (change-prone variables)>
      send(active_admin_namespace.authentication_method) if active_admin_namespace.authentication_method
    end

    def current_active_admin_user
      #nodyna <send-115> <SD COMPLEX (change-prone variables)>
      send(active_admin_namespace.current_user_method) if active_admin_namespace.current_user_method
    end
    helper_method :current_active_admin_user

    def current_active_admin_user?
      !!current_active_admin_user
    end
    helper_method :current_active_admin_user?

    def active_admin_config
      self.class.active_admin_config
    end
    helper_method :active_admin_config

    def active_admin_namespace
      active_admin_config.namespace
    end
    helper_method :active_admin_namespace


    ACTIVE_ADMIN_ACTIONS = [:index, :show, :new, :create, :edit, :update, :destroy]

    def determine_active_admin_layout
      ACTIVE_ADMIN_ACTIONS.include?(params[:action].to_sym) ? false : 'active_admin'
    end

  end
end
