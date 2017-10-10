class SetShipmentTotalForUsersUpgrading < ActiveRecord::Migration
  def up
    Spree::Order.complete.where('shipment_total = ?', 0).includes(:shipments).find_each do |order|
      order.update_column(:shipment_total, order.shipments.sum(:cost))
    end
  end
end
