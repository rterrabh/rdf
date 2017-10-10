module Spree
  class Adjustment < Spree::Base
    belongs_to :adjustable, polymorphic: true, touch: true
    belongs_to :source, polymorphic: true
    belongs_to :order, class_name: 'Spree::Order', inverse_of: :all_adjustments

    validates :adjustable, presence: true
    validates :order, presence: true
    validates :label, presence: true
    validates :amount, numericality: true

    state_machine :state, initial: :open do
      event :close do
        transition from: :open, to: :closed
      end

      event :open do
        transition from: :closed, to: :open
      end
    end

    after_create :update_adjustable_adjustment_total
    after_destroy :update_adjustable_adjustment_total

    class_attribute :competing_promos_source_types

    self.competing_promos_source_types = ['Spree::PromotionAction']

    scope :open, -> { where(state: 'open') }
    scope :closed, -> { where(state: 'closed') }
    scope :tax, -> { where(source_type: 'Spree::TaxRate') }
    scope :non_tax, -> do
      source_type = arel_table[:source_type]
      where(source_type.not_eq('Spree::TaxRate').or source_type.eq(nil))
    end
    scope :price, -> { where(adjustable_type: 'Spree::LineItem') }
    scope :shipping, -> { where(adjustable_type: 'Spree::Shipment') }
    scope :optional, -> { where(mandatory: false) }
    scope :eligible, -> { where(eligible: true) }
    scope :charge, -> { where("#{quoted_table_name}.amount >= 0") }
    scope :credit, -> { where("#{quoted_table_name}.amount < 0") }
    scope :nonzero, -> { where("#{quoted_table_name}.amount != 0") }
    scope :promotion, -> { where(source_type: 'Spree::PromotionAction') }
    scope :return_authorization, -> { where(source_type: "Spree::ReturnAuthorization") }
    scope :is_included, -> { where(included: true) }
    scope :additional, -> { where(included: false) }
    scope :competing_promos, -> { where(source_type: competing_promos_source_types) }

    extend DisplayMoney
    money_methods :amount

    def closed?
      state == "closed"
    end

    def currency
      adjustable ? adjustable.currency : Spree::Config[:currency]
    end

    def promotion?
      source_type == 'Spree::PromotionAction'
    end

    def update!(target = adjustable)
      return amount if closed? || source.blank?
      amount = source.compute_amount(target)
      attributes = { amount: amount, updated_at: Time.now }
      attributes[:eligible] = source.promotion.eligible?(target) if promotion?
      update_columns(attributes)
      amount
    end

    private

    def update_adjustable_adjustment_total
      Adjustable::AdjustmentsUpdater.update(adjustable)
    end

  end
end
