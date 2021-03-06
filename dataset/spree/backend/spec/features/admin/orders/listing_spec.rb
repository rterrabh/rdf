require 'spec_helper'

describe "Orders Listing", type: :feature do
  stub_authorization!

  let(:order1) do
    create :order_with_line_items,
      created_at: 1.day.from_now,
      completed_at: 1.day.from_now,
      considered_risky: true,
      number: "R100"
  end

  let(:order2) do
    create :order,
      created_at: 1.day.ago,
      completed_at: 1.day.ago,
      number: "R200"
  end

  before do
    allow_any_instance_of(Spree::OrderInventory).to receive(:add_to_shipment)
    order1; order2
    visit spree.admin_orders_path
  end

  describe "listing orders" do
    it "should list existing orders" do
      within_row(1) do
        expect(column_text(2)).to eq "R100"
        expect(find("td:nth-child(3)")).to have_css '.label-considered_risky'
        expect(column_text(4)).to eq "cart"
      end

      within_row(2) do
        expect(column_text(2)).to eq "R200"
        expect(find("td:nth-child(3)")).to have_css '.label-considered_safe'
      end
    end

    it "should be able to sort the orders listing" do
      within_row(1) { expect(page).to have_content("R100") }
      within_row(2) { expect(page).to have_content("R200") }

      click_link "Completed At"

      within_row(1) { expect(page).to have_content("R200") }
      within_row(2) { expect(page).to have_content("R100") }

      within('table#listing_orders thead') { click_link "Number" }

      within_row(1) { expect(page).to have_content("R100") }
      within_row(2) { expect(page).to have_content("R200") }
    end
  end

  describe "searching orders" do
    it "should be able to search orders" do
      fill_in "q_number_cont", with: "R200"
      click_on 'Filter Results'
      within_row(1) do
        expect(page).to have_content("R200")
      end

      within("table#listing_orders") { expect(page).not_to have_content("R100") }
    end

    it "should return both complete and incomplete orders when only complete orders is not checked" do
      Spree::Order.create! email: "incomplete@example.com", completed_at: nil, state: 'cart'
      click_on 'Filter'
      uncheck "q_completed_at_not_null"
      click_on 'Filter Results'

      expect(page).to have_content("R200")
      expect(page).to have_content("incomplete@example.com")
    end

    it "should be able to filter risky orders" do
      check "q_considered_risky_eq"
      click_on 'Filter Results'

      expect(find("#q_considered_risky_eq")).to be_checked
      within_row(1) do
        expect(page).to have_content("R100")
      end
      expect(page).not_to have_content("R200")
    end

    it "should be able to filter on variant_id" do
      expect(find('#q_line_items_variant_id_in').all('option').collect(&:text)).to include(order1.line_items.first.variant.sku)

      find('#q_line_items_variant_id_in').find(:xpath, 'option[2]').select_option
      click_on 'Filter Results'

      within_row(1) do
        expect(page).to have_content(order1.number)
      end

      expect(page).not_to have_content(order2.number)
    end

    context "when pagination is really short" do
      before do
        @old_per_page = Spree::Config[:orders_per_page]
        Spree::Config[:orders_per_page] = 1
      end

      after do
        Spree::Config[:orders_per_page] = @old_per_page
      end

      it "should be able to go from page to page for incomplete orders" do
        Spree::Order.destroy_all
        2.times { Spree::Order.create! email: "incomplete@example.com", completed_at: nil, state: 'cart' }
        click_on 'Filter'
        uncheck "q_completed_at_not_null"
        click_on 'Filter Results'
        within(".pagination") do
          click_link "2"
        end
        expect(page).to have_content("incomplete@example.com")
        expect(find("#q_completed_at_not_null")).not_to be_checked
      end
    end

    it "should be able to search orders using only completed at input" do
      fill_in "q_created_at_gt", with: Date.current
      click_on 'Filter Results'

      within_row(1) { expect(page).to have_content("R100") }

      within("table#listing_orders") { expect(page).not_to have_content("R200") }
    end

    context "filter on promotions" do
      let!(:promotion) { create(:promotion_with_item_adjustment) }

      before do
        order1.promotions << promotion
        order1.save
        visit spree.admin_orders_path
      end

      it "only shows the orders with the selected promotion" do
        select promotion.name, from: "Promotion"
        click_on 'Filter Results'
        within_row(1) { expect(page).to have_content("R100") }
        within("table#listing_orders") { expect(page).not_to have_content("R200") }
      end
    end

    it "should be able to apply a ransack filter by clicking a quickfilter icon", js: true do
      label_pending = page.find '.label-pending'
      parent_td = label_pending.find(:xpath, '..')

      within(parent_td) do
        find('.js-add-filter').click
      end

      expect(page).to have_content("R100")
      expect(page).not_to have_content("R200")
    end

    context "filter on shipment state" do
      it "only shows the orders with the selected shipment state" do
        select Spree.t("payment_states.#{order1.shipment_state}"), from: "Shipment State"
        click_on 'Filter Results'
        within_row(1) { expect(page).to have_content("R100") }
        within("table#listing_orders") { expect(page).not_to have_content("R200") }
      end
    end

    context "filter on payment state" do
      it "only shows the orders with the selected payment state" do
        select Spree.t("payment_states.#{order1.payment_state}"), from: "Payment State"
        click_on 'Filter Results'
        within_row(1) { expect(page).to have_content("R100") }
        within("table#listing_orders") { expect(page).not_to have_content("R200") }
      end
    end
  end
end
