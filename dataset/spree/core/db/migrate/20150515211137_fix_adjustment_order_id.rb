class FixAdjustmentOrderId < ActiveRecord::Migration
  def change
    say 'Populate order_id from adjustable_id where appropriate'
    execute(<<-SQL.squish)
      UPDATE
        spree_adjustments
      SET
        order_id = adjustable_id
      WHERE
        adjustable_type = 'Spree::Order'
      ;
    SQL

    if Spree::Order.connection.adapter_name.eql?('MySQL')
      Spree::Adjustment.where(adjustable_type: 'Spree::LineItem').find_each do |adjustment|
        adjustment.update_columns(order_id: Spree::LineItem.find(adjustment.adjustable_id).order_id)
      end
    else
      execute(<<-SQL.squish)
        UPDATE
          spree_adjustments
        SET
          order_id =
            (SELECT order_id FROM spree_line_items WHERE spree_line_items.id = spree_adjustments.adjustable_id)
        WHERE
          adjustable_type = 'Spree::LineItem'
      SQL
    end

    say 'Fix schema for spree_adjustments order_id column'
    change_table :spree_adjustments do |t|
      t.change :order_id, :integer, null: false
    end

  end
end
