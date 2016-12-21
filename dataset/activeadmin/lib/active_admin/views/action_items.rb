module ActiveAdmin
  module Views

    class ActionItems < ActiveAdmin::Component

      def build(action_items)
        action_items.each do |action_item|
          span class: "action_item" do
            #nodyna <ID:instance_exec-23> <instance_exec VERY HIGH ex1>
            instance_exec(&action_item.block)
          end
        end
      end

    end

  end
end
