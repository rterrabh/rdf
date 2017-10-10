
module ActionController
  module HideActions
    extend ActiveSupport::Concern

    included do
      class_attribute :hidden_actions
      self.hidden_actions = Set.new.freeze
    end

  private

    def method_for_action(action_name)
      self.class.visible_action?(action_name) && super
    end

    module ClassMethods
      def hide_action(*args)
        self.hidden_actions = hidden_actions.dup.merge(args.map(&:to_s)).freeze
      end

      def visible_action?(action_name)
        not hidden_actions.include?(action_name)
      end

      def action_methods
        @action_methods ||= Set.new(super.reject { |name| hidden_actions.include?(name) }).freeze
      end
    end
  end
end
