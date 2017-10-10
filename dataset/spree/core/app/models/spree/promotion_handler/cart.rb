module Spree
  module PromotionHandler
    class Cart
      attr_reader :line_item, :order
      attr_accessor :error, :success

      def initialize(order, line_item=nil)
        @order, @line_item = order, line_item
      end

      def activate
        promotions.each do |promotion|
          if (line_item && promotion.eligible?(line_item)) || promotion.eligible?(order)
            promotion.activate(line_item: line_item, order: order)
          end
        end
      end

      private

      def promotions
        select = Arel::SelectManager.new(
          Promotion,
          Promotion.arel_table.create_table_alias(
            order.promotions.active.union(Promotion.active.where(code: nil, path: nil)),
            Promotion.table_name
          ),
        )
        select.project(Arel.star)

        Promotion.find_by_sql(
          select,
          order.promotions.bind_values
        )
      end
    end
  end
end
