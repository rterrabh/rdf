module Spree


  class ReimbursementTaxCalculator

    class << self

      def call(reimbursement)
        reimbursement.return_items.includes(:inventory_unit).each do |return_item|
          set_tax!(return_item)
        end
      end

      private

      def set_tax!(return_item)
        calculated_refund = Spree::ReturnItem.refund_amount_calculator.new.compute(return_item)

        percent_of_tax = if return_item.pre_tax_amount <= 0 || calculated_refund <= 0
          0
        else
          return_item.pre_tax_amount / calculated_refund
        end

        additional_tax_total = percent_of_tax * return_item.inventory_unit.additional_tax_total
        included_tax_total   = percent_of_tax * return_item.inventory_unit.included_tax_total

        return_item.update_attributes!({
          additional_tax_total: additional_tax_total,
          included_tax_total:   included_tax_total,
        })
      end
    end

  end

end
