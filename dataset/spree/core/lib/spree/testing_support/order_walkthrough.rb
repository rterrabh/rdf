class OrderWalkthrough
  def self.up_to(state)
    unless Spree::Store.exists?
      FactoryGirl.create(:store)
    end

    unless Spree::PaymentMethod.exists?
      FactoryGirl.create(:check_payment_method)
    end

    zone = FactoryGirl.create(:zone)
    country = FactoryGirl.create(:country)
    zone.members << Spree::ZoneMember.create(:zoneable => country)
    country.states << FactoryGirl.create(:state, :country => country)

    unless Spree::ShippingMethod.exists?
      FactoryGirl.create(:shipping_method).tap do |sm|
        sm.calculator.preferred_amount = 10
        sm.calculator.preferred_currency = Spree::Config[:currency]
        sm.calculator.save
      end
    end

    order = Spree::Order.create!(email: "spree@example.com")
    add_line_item!(order)
    order.next!

    end_state_position = states.index(state.to_sym)
    states[0...end_state_position].each do |state|
      #nodyna <send-2551> <SD MODERATE (array)>
      send(state, order)
    end

    order
  end

  private

  def self.add_line_item!(order)
    FactoryGirl.create(:line_item, order: order)
    order.reload
  end

  def self.address(order)
    order.bill_address = FactoryGirl.create(:address, :country_id => Spree::Zone.global.members.first.zoneable.id)
    order.ship_address = FactoryGirl.create(:address, :country_id => Spree::Zone.global.members.first.zoneable.id)
    order.next!
  end

  def self.delivery(order)
    order.next!
  end

  def self.payment(order)
    order.payments.create!(payment_method: Spree::PaymentMethod.first, amount: order.total)
    order.payment_state = 'paid'
    order.next!
  end

  def self.complete(order)
  end

  def self.states
    [:address, :delivery, :payment, :complete]
  end

end
