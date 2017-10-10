require 'active_admin/helpers/optional_display'

module ActiveAdmin

  class Resource
    module ActionItems

      def initialize(*args)
        super
        add_default_action_items
      end

      def action_items
        @action_items ||= []
      end

      def add_action_item(name, options = {}, &block)
        self.action_items << ActiveAdmin::ActionItem.new(name, options, &block)
      end

      def remove_action_item(name)
        self.action_items.delete_if { |item| item.name == name }
      end

      def action_items_for(action, render_context = nil)
        action_items.select{ |item| item.display_on? action, render_context }
      end

      def clear_action_items!
        @action_items = []
      end

      def action_items?
        !!@action_items && @action_items.any?
      end

      private

      def add_default_action_items
        add_action_item :new, only: :index do
          if controller.action_methods.include?('new') && authorized?(ActiveAdmin::Auth::CREATE, active_admin_config.resource_class)
            link_to I18n.t('active_admin.new_model', model: active_admin_config.resource_label), new_resource_path
          end
        end

        add_action_item :edit, only: :show do
          if controller.action_methods.include?('edit') && authorized?(ActiveAdmin::Auth::UPDATE, resource)
            link_to I18n.t('active_admin.edit_model', model: active_admin_config.resource_label), edit_resource_path(resource)
          end
        end

        add_action_item :destroy, only: :show do
          if controller.action_methods.include?('destroy') && authorized?(ActiveAdmin::Auth::DESTROY, resource)
            link_to I18n.t('active_admin.delete_model', model: active_admin_config.resource_label), resource_path(resource),
              method: :delete, data: {confirm: I18n.t('active_admin.delete_confirmation')}
          end
        end
      end

    end
  end

  class ActionItem
    include ActiveAdmin::OptionalDisplay

    attr_accessor :block, :name

    def initialize(name, options = {}, &block)
      @name = name
      @options = options
      @block = block
      normalize_display_options!
    end
  end

end
