require 'active_admin/resource_controller/action_builder'
require 'active_admin/resource_controller/data_access'
require 'active_admin/resource_controller/decorators'
require 'active_admin/resource_controller/scoping'
require 'active_admin/resource_controller/streaming'
require 'active_admin/resource_controller/sidebars'
require 'active_admin/resource_controller/resource_class_methods'

module ActiveAdmin
  class ResourceController < BaseController
    layout :determine_active_admin_layout

    respond_to :html, :xml, :json
    respond_to :csv, only: :index

    include ActionBuilder
    include Decorators
    include DataAccess
    include Scoping
    include Streaming
    include Sidebars
    extend  ResourceClassMethods

    def self.active_admin_config=(config)
      if @active_admin_config = config
        defaults resource_class: config.resource_class,
                 route_prefix:   config.route_prefix,
                 instance_name:  config.resource_name.singular
      end
    end

    def self.inherited(base)
      super(base)
      base.override_resource_class_methods!
    end

    private

    def renderer_for(action)
      active_admin_namespace.view_factory["#{action}_page"]
    end
    helper_method :renderer_for

  end
end
