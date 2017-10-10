require 'active_admin/component'

module ActiveAdmin
  module BatchActions

    class BatchActionForm < ActiveAdmin::Component
      builder_method :batch_action_form

      attr_reader :prefix_html

      def build(options = {}, &block)
        options[:id] ||= "collection_selection"

        text_node form_tag active_admin_config.batch_action_path(params), id: options[:id]
        input name: :batch_action,        id: :batch_action,        type: :hidden
        input name: :batch_action_inputs, id: :batch_action_inputs, type: :hidden

        super(options)
      end

      def to_s
        content + closing_form_tag
      end

      private

      def closing_form_tag
        '</form>'.html_safe
      end

    end
  end
end
