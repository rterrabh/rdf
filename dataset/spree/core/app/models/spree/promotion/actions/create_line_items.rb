module Spree
  class Promotion
    module Actions
      class CreateLineItems < PromotionAction
        has_many :promotion_action_line_items, foreign_key: :promotion_action_id
        accepts_nested_attributes_for :promotion_action_line_items

        delegate :eligible?, :to => :promotion

        def perform(options = {})
          order = options[:order]
          return unless self.eligible? order

          action_taken = false
          promotion_action_line_items.each do |item|
            current_quantity = order.quantity_of(item.variant)
            if current_quantity < item.quantity && item_available?(item)
              line_item = order.contents.add(item.variant, item.quantity - current_quantity)
              action_taken = true if line_item.try(:valid?)
            end
          end
          action_taken
        end

        def item_available?(item)
          quantifier = Spree::Stock::Quantifier.new(item.variant)
          quantifier.can_supply? item.quantity
        end

      end
    end
  end
end
