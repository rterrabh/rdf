module ActiveAdmin

  module BatchActions
    module ResourceExtension
      def initialize(*)
        super
        @batch_actions = {}
        add_default_batch_action
      end

      def batch_actions
        batch_actions_enabled? ? @batch_actions.values.sort : []
      end

      def batch_actions_enabled?
        @batch_actions_enabled.nil? ? namespace.batch_actions : @batch_actions_enabled
      end

      def batch_actions=(bool)
        @batch_actions_enabled = bool
      end

      def add_batch_action(sym, title, options = {}, &block)
        @batch_actions[sym] = ActiveAdmin::BatchAction.new(sym, title, options, &block)
      end

      def remove_batch_action(sym)
        @batch_actions.delete(sym.to_sym)
      end

      def clear_batch_actions!
        @batch_actions = {}
      end

      def batch_action_path(params = {})
        [route_collection_path(params), "batch_action"].join("/")
      end

      private

      def add_default_batch_action
        destroy_options = {
          priority: 100,
          confirm: proc{ I18n.t('active_admin.batch_actions.delete_confirmation', plural_model: active_admin_config.plural_resource_label.downcase) },
          if: proc{ controller.action_methods.include?('destroy') && authorized?(ActiveAdmin::Auth::DESTROY, active_admin_config.resource_class) }
        }

        add_batch_action :destroy, proc { I18n.t('active_admin.delete') }, destroy_options do |selected_ids|
          batch_action_collection.find(selected_ids).each do |record|
            authorize! ActiveAdmin::Auth::DESTROY, record
            destroy_resource(record)
          end

          redirect_to active_admin_config.route_collection_path(params),
                      notice: I18n.t("active_admin.batch_actions.succesfully_destroyed",
                                        count: selected_ids.count,
                                        model: active_admin_config.resource_label.downcase,
                                        plural_model: active_admin_config.plural_resource_label(count: selected_ids.count).downcase)
        end
      end

    end
  end

  class BatchAction

    include Comparable

    attr_reader :block, :title, :sym

    DEFAULT_CONFIRM_MESSAGE = proc{ I18n.t 'active_admin.batch_actions.default_confirmation' }

    def initialize(sym, title, options = {}, &block)
      @sym, @title, @options, @block, @confirm = sym, title, options, block, options[:confirm]
      @block ||= proc {}
    end

    def confirm
      if @confirm == true
        DEFAULT_CONFIRM_MESSAGE
      elsif !@confirm && @options[:form]
        DEFAULT_CONFIRM_MESSAGE
      else
        @confirm
      end
    end

    def inputs
      @options[:form]
    end

    def display_if_block
      @options[:if] || proc{ true }
    end

    def priority
      @options[:priority] || 10
    end

    def <=>(other)
      self.priority <=> other.priority
    end

  end

end
