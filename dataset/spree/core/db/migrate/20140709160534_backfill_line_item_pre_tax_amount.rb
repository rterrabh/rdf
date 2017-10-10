class BackfillLineItemPreTaxAmount < ActiveRecord::Migration
  def change
    execute(<<-SQL)
      UPDATE spree_line_items
      SET pre_tax_amount = ((price * quantity) + promo_total) - included_tax_total
      WHERE pre_tax_amount IS NULL;
    SQL
  end
end
