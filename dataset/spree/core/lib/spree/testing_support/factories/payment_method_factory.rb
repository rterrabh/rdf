FactoryGirl.define do
  factory :check_payment_method, class: Spree::PaymentMethod::Check do
    name 'Check'
  end

  factory :credit_card_payment_method, class: Spree::Gateway::Bogus do
    name 'Credit Card'
  end

  factory :simple_credit_card_payment_method, class: Spree::Gateway::BogusSimple do
    name 'Credit Card'
  end
end
