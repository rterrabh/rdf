require 'spec_helper'

describe "Customer Details", type: :feature, js: true do
  stub_authorization!

  let(:country) { create(:country, name: "Kangaland") }
  let(:state) { create(:state, name: "Alabama", country: country) }
  let!(:shipping_method) { create(:shipping_method, display_on: "front_end") }
  let!(:order) { create(:order, state: 'complete', completed_at: "2011-02-01 12:36:15") }
  let!(:product) { create(:product_in_stock) }

  let!(:ship_address) { create(:address, country: country, state: state, first_name: "Rumpelstiltskin") }
  let!(:bill_address) { create(:address, country: country, state: state, first_name: "Rumpelstiltskin") }

  let!(:user) { create(:user, email: 'foobar@example.com', ship_address: ship_address, bill_address: bill_address) }

  def wait_for_condition
    time = Capybara.default_wait_time
    step = 0.1
    while time > 0
      return if yield
      sleep(step)
      time -= 0.1
    end
    fail "Could archieve condition within #{Capybara.default_wait_time} seconds"
  end

  def expect_form_value(id, value)
    node = page.find(id)
    wait_for_condition { node.value.eql?(value) }
  end

  context "brand new order" do
    before do
      visit spree.new_admin_order_path
    end
    it "associates a user when not using guest checkout" do
      select2_search product.name, from: Spree.t(:name_or_sku)
      within("table.stock-levels") do
        fill_in "variant_quantity", with: 1
        click_icon :add
      end
      wait_for_ajax
      click_link "Customer"
      targetted_select2 "foobar@example.com", from: "#s2id_customer_search"
      expect_form_value('#order_bill_address_attributes_firstname', user.bill_address.firstname)
      expect_form_value('#order_bill_address_attributes_lastname', user.bill_address.lastname)
      expect_form_value('#order_bill_address_attributes_address1', user.bill_address.address1)
      expect_form_value('#order_bill_address_attributes_address2', user.bill_address.address2)
      expect_form_value('#order_bill_address_attributes_city', user.bill_address.city)
      expect_form_value('#order_bill_address_attributes_zipcode', user.bill_address.zipcode)
      expect_form_value('#order_bill_address_attributes_country_id', user.bill_address.country_id.to_s)
      expect_form_value('#order_bill_address_attributes_state_id', user.bill_address.state_id.to_s)
      expect_form_value('#order_bill_address_attributes_phone', user.bill_address.phone)
      click_button "Update"
      expect(Spree::Order.last.user).not_to be_nil
    end
  end

  context "editing an order" do
    before do
      configure_spree_preferences do |config|
        config.default_country_id = country.id
        config.company = true
      end

      visit spree.admin_orders_path
      within('table#listing_orders') { click_icon(:edit) }
    end

    context "selected country has no state" do
      before { create(:country, iso: "BRA", name: "Brazil") }

      it "changes state field to text input" do
        click_link "Customer"

        within("#billing") do
          targetted_select2 "Brazil", from: "#s2id_order_bill_address_attributes_country_id"
          fill_in "order_bill_address_attributes_state_name", with: "Piaui"
        end

        click_button "Update"
        expect(find_field("order_bill_address_attributes_state_name").value).to eq("Piaui")
      end
    end

    it "should be able to update customer details for an existing order" do
      order.ship_address = create(:address)
      order.save!

      click_link "Customer"
      within("#shipping") { fill_in_address "ship" }
      within("#billing") { fill_in_address "bill" }

      click_button "Update"
      click_link "Customer"

      within("#order_tab_summary") do
        expect(find(".state").text).to eq("complete")
      end
    end

    it "should show validation errors" do
      click_link "Customer"
      click_button "Update"
      expect(page).to have_content("Shipping address first name can't be blank")
    end

    it "updates order email for an existing order with a user" do
      order.update_columns(ship_address_id: ship_address.id, bill_address_id: bill_address.id, state: "confirm", completed_at: nil)
      previous_user = order.user
      click_link "Customer"
      fill_in "order_email", with: "newemail@example.com"
      expect { click_button "Update" }.to change { order.reload.email }.to "newemail@example.com"
      expect(order.user_id).to eq previous_user.id
      expect(order.user.email).to eq previous_user.email
    end

    context "country associated was removed" do
      let(:brazil) { create(:country, iso: "BRA", name: "Brazil") }

      before do
        order.bill_address.country.destroy
        configure_spree_preferences do |config|
          config.default_country_id = brazil.id
        end
      end

      it "sets default country when displaying form" do
        click_link "Customer"
        expect(find_field("order_bill_address_attributes_country_id").value.to_i).to eq brazil.id
      end
    end

    context "errors when no shipping methods are available" do
      before do
        Spree::ShippingMethod.delete_all
      end

      specify do
        click_link "Customer"
        fill_in "order_ship_address_attributes_firstname",  with: "John 99"
        fill_in "order_ship_address_attributes_lastname",   with: "Doe"
        fill_in "order_ship_address_attributes_lastname",   with: "Company"
        fill_in "order_ship_address_attributes_address1",   with: "100 first lane"
        fill_in "order_ship_address_attributes_address2",   with: "#101"
        fill_in "order_ship_address_attributes_city",       with: "Bethesda"
        fill_in "order_ship_address_attributes_zipcode",    with: "20170"

        page.select('Alabama', from: 'order_ship_address_attributes_state_id')
        fill_in "order_ship_address_attributes_phone", with: "123-456-7890"
        expect { click_button "Update" }.not_to raise_error
      end
    end
  end

  def fill_in_address(kind = "bill")
    fill_in "First Name",              with: "John 99"
    fill_in "Last Name",               with: "Doe"
    fill_in "Company",                 with: "Company"
    fill_in "Street Address",          with: "100 first lane"
    fill_in "Street Address (cont'd)", with: "#101"
    fill_in "City",                    with: "Bethesda"
    fill_in "Zip",                     with: "20170"
    targetted_select2 "Alabama",       from: "#s2id_order_#{kind}_address_attributes_state_id"
    fill_in "Phone",                   with: "123-456-7890"
  end
end
