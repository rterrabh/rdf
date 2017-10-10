module Spree
  class OrderUpdater
    attr_reader :order
    delegate :payments, :line_items, :adjustments, :all_adjustments, :shipments, :update_hooks, :quantity, to: :order

    def initialize(order)
      @order = order
    end

    def update
      update_totals
      if order.completed?
        update_payment_state
        update_shipments
        update_shipment_state
      end
      run_hooks
      persist_totals
    end

    def run_hooks
      #nodyna <send-2503> <SD COMPLEX (array)>
      update_hooks.each { |hook| order.send hook }
    end

    def recalculate_adjustments
      all_adjustments.includes(:adjustable).map(&:adjustable).uniq.each do |adjustable|
        Adjustable::AdjustmentsUpdater.update(adjustable)
      end
    end

    def update_totals
      update_payment_total
      update_item_total
      update_shipment_total
      update_adjustment_total
    end


    def update_shipments
      shipments.each do |shipment|
        next unless shipment.persisted?
        shipment.update!(order)
        shipment.refresh_rates
        shipment.update_amounts
      end
    end

    def update_payment_total
      order.payment_total = payments.completed.includes(:refunds).inject(0) { |sum, payment| sum + payment.amount - payment.refunds.sum(:amount) }
    end

    def update_shipment_total
      order.shipment_total = shipments.sum(:cost)
      update_order_total
    end

    def update_order_total
      order.total = order.item_total + order.shipment_total + order.adjustment_total
    end

    def update_adjustment_total
      recalculate_adjustments
      order.adjustment_total = line_items.sum(:adjustment_total) +
                               shipments.sum(:adjustment_total)  +
                               adjustments.eligible.sum(:amount)
      order.included_tax_total = line_items.sum(:included_tax_total) + shipments.sum(:included_tax_total)
      order.additional_tax_total = line_items.sum(:additional_tax_total) + shipments.sum(:additional_tax_total)

      order.promo_total = line_items.sum(:promo_total) +
                          shipments.sum(:promo_total) +
                          adjustments.promotion.eligible.sum(:amount)

      update_order_total
    end

    def update_item_count
      order.item_count = quantity
    end

    def update_item_total
      order.item_total = line_items.sum('price * quantity')
      update_order_total
    end

    def persist_totals
      order.update_columns(
        payment_state: order.payment_state,
        shipment_state: order.shipment_state,
        item_total: order.item_total,
        item_count: order.item_count,
        adjustment_total: order.adjustment_total,
        included_tax_total: order.included_tax_total,
        additional_tax_total: order.additional_tax_total,
        payment_total: order.payment_total,
        shipment_total: order.shipment_total,
        promo_total: order.promo_total,
        total: order.total,
        updated_at: Time.now,
      )
    end

    def update_shipment_state
      if order.backordered?
        order.shipment_state = 'backorder'
      else
        shipment_states = shipments.states
        if shipment_states.size > 1
          order.shipment_state = 'partial'
        else
          order.shipment_state = shipment_states.first
        end
      end

      order.state_changed('shipment')
      order.shipment_state
    end

    def update_payment_state
      last_state = order.payment_state
      if payments.present? && payments.valid.size == 0
        order.payment_state = 'failed'
      elsif order.state == 'canceled' && order.payment_total == 0
        order.payment_state = 'void'
      else
        order.payment_state = 'balance_due' if order.outstanding_balance > 0
        order.payment_state = 'credit_owed' if order.outstanding_balance < 0
        order.payment_state = 'paid' if !order.outstanding_balance?
      end
      order.state_changed('payment') if last_state != order.payment_state
      order.payment_state
    end

    private
      def round_money(n)
        (n * 100).round / 100.0
      end
  end
end
