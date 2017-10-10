class CreateSpreeShippingRates < ActiveRecord::Migration
  def up
    create_table :spree_shipping_rates do |t|
      t.belongs_to :shipment
      t.belongs_to :shipping_method
      t.boolean :selected, :default => false
      t.decimal :cost, :precision => 8, :scale => 2
      t.timestamps null: false
    end
    add_index(:spree_shipping_rates, [:shipment_id, :shipping_method_id],
              :name => 'spree_shipping_rates_join_index',
              :unique => true)

  end

  def down
    drop_table :spree_shipping_rates
  end
end
