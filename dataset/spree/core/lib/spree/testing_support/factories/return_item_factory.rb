FactoryGirl.define do
  factory :return_item, class: Spree::ReturnItem do
    association(:inventory_unit, factory: :inventory_unit, state: :shipped)
    association(:return_authorization, factory: :return_authorization)

    factory :exchange_return_item do
      after(:build) do |return_item|
        return_item.inventory_unit.variant.update_column(:track_inventory, false)
        return_item.exchange_variant = return_item.inventory_unit.variant
      end
    end
  end
end
