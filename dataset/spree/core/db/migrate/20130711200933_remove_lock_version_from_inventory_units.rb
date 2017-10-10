class RemoveLockVersionFromInventoryUnits < ActiveRecord::Migration
  def change
    remove_column :spree_inventory_units, :lock_version
  end
end
