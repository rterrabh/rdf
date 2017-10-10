class RemoveStockItemAndVariantLock < ActiveRecord::Migration
  def up
    remove_column :spree_stock_items, :lock_version

    remove_column :spree_variants, :lock_version
  end

  def down
    add_column :spree_stock_items, :lock_version, :integer
    add_column :spree_variants, :lock_version, :integer
  end
end
