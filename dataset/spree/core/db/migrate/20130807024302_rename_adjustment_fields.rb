class RenameAdjustmentFields < ActiveRecord::Migration
  def up
    remove_column :spree_adjustments, :originator_id
    remove_column :spree_adjustments, :originator_type

    add_column :spree_adjustments, :order_id, :integer unless column_exists?(:spree_adjustments, :order_id)

    Spree::Adjustment.reset_column_information
    Spree::Adjustment.where(adjustable_type: "Spree::Order").find_each do |adjustment|
      adjustment.update_column(:order_id, adjustment.adjustable_id)
    end
  end
end
