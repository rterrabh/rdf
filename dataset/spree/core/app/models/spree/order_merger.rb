module Spree
  class OrderMerger
    attr_accessor :order
    delegate :updater, to: :order

    def initialize(order)
      @order = order
    end

    def merge!(other_order, user = nil)
      other_order.line_items.each do |other_order_line_item|
        next unless other_order_line_item.currency == order.currency

        current_line_item = find_matching_line_item(other_order_line_item)
        handle_merge(current_line_item, other_order_line_item)
      end

      set_user(user)
      persist_merge

      other_order.line_items.reload
      other_order.destroy
    end

    def find_matching_line_item(other_order_line_item)
      order.line_items.detect do |my_li|
        my_li.variant == other_order_line_item.variant &&
          order.line_item_comparison_hooks.all? do |hook|
            #nodyna <send-2528> <SD COMPLEX (array)>
            order.send(hook, my_li, other_order_line_item.serializable_hash)
          end
      end
    end

    def set_user(user = nil)
      order.associate_user!(user) if !order.user && !user.blank?
    end

    def handle_merge(current_line_item, other_order_line_item)
      if current_line_item
        current_line_item.quantity += other_order_line_item.quantity
        handle_error(current_line_item) unless current_line_item.save
      else
        other_order_line_item.order_id = order.id
        handle_error(other_order_line_item) unless other_order_line_item.save
      end
    end

    def handle_error(line_item)
      order.errors[:base] << line_item.errors.full_messages
    end

    def persist_merge
      updater.update_item_count
      updater.update_item_total
      updater.persist_totals
    end
  end
end
