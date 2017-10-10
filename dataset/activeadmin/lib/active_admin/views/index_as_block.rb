module ActiveAdmin
  module Views

    class IndexAsBlock < ActiveAdmin::Component

      def build(page_presenter, collection)
        add_class "index"
        resource_selection_toggle_panel if active_admin_config.batch_actions.any?
        collection.each do |obj|
          #nodyna <instance_exec-60> <IEX COMPLEX (block with parameters)>
          instance_exec(obj, &page_presenter.block)
        end
      end

      def self.index_name
        "block"
      end

    end
  end
end
