class AddTaxTotalToLineItemsShipmentsAndOrders < ActiveRecord::Migration
  def change
    add_column :spree_line_items, :tax_total, :decimal, precision: 10, scale: 2, default: 0.0
    add_column :spree_shipments, :tax_total, :decimal, precision: 10, scale: 2, default: 0.0
    add_column :spree_orders, :tax_total, :decimal, precision: 10, scale: 2, default: 0.0 unless Spree::Order.column_names.include?("tax_total")
  end
end
