module Spree
  class Reimbursement < Spree::Base
    class IncompleteReimbursementError < StandardError; end

    belongs_to :order, inverse_of: :reimbursements
    belongs_to :customer_return, inverse_of: :reimbursements, touch: true

    has_many :refunds, inverse_of: :reimbursement
    has_many :credits, inverse_of: :reimbursement, class_name: 'Spree::Reimbursement::Credit'

    has_many :return_items, inverse_of: :reimbursement

    validates :order, presence: true
    validate :validate_return_items_belong_to_same_order

    accepts_nested_attributes_for :return_items, allow_destroy: true

    before_create :generate_number

    scope :reimbursed, -> { where(reimbursement_status: 'reimbursed') }

    class_attribute :reimbursement_tax_calculator
    self.reimbursement_tax_calculator = ReimbursementTaxCalculator
    class_attribute :reimbursement_simulator_tax_calculator
    self.reimbursement_simulator_tax_calculator = ReimbursementTaxCalculator

    class_attribute :reimbursement_models
    self.reimbursement_models = [Refund]

    class_attribute :reimbursement_performer
    self.reimbursement_performer = ReimbursementPerformer

    class_attribute :reimbursement_success_hooks
    self.reimbursement_success_hooks = []

    class_attribute :reimbursement_failure_hooks
    self.reimbursement_failure_hooks = []

    state_machine :reimbursement_status, initial: :pending do

      event :errored do
        transition to: :errored, from: :pending
      end

      event :reimbursed do
        transition to: :reimbursed, from: [:pending, :errored]
      end

    end

    class << self
      def build_from_customer_return(customer_return)
        order = customer_return.order
        order.reimbursements.build({
          customer_return: customer_return,
          return_items: customer_return.return_items.accepted.not_reimbursed,
        })
      end
    end

    def display_total
      Spree::Money.new(total, { currency: order.currency })
    end

    def calculated_total
      return_items.map { |ri| ri.total.to_d.round(2) }.sum
    end

    def paid_amount
      reimbursement_models.sum do |model|
        model.total_amount_reimbursed_for(self)
      end
    end

    def unpaid_amount
      total - paid_amount
    end

    def perform!
      reimbursement_tax_calculator.call(self)
      reload
      update!(total: calculated_total)

      reimbursement_performer.perform(self)

      if unpaid_amount_within_tolerance?
        reimbursed!
        reimbursement_success_hooks.each { |h| h.call self }
        send_reimbursement_email
      else
        errored!
        reimbursement_failure_hooks.each { |h| h.call self }
        raise IncompleteReimbursementError, Spree.t("validation.unpaid_amount_not_zero", amount: unpaid_amount)
      end
    end

    def simulate
      reimbursement_simulator_tax_calculator.call(self)
      reload
      update!(total: calculated_total)

      reimbursement_performer.simulate(self)
    end

    def return_items_requiring_exchange
      return_items.select(&:exchange_required?)
    end

    private

    def generate_number
      self.number ||= loop do
        random = "RI#{Array.new(9){rand(9)}.join}"
        break random unless self.class.exists?(number: random)
      end
    end

    def validate_return_items_belong_to_same_order
      if return_items.any? { |ri| ri.inventory_unit.order_id != order_id }
        errors.add(:base, :return_items_order_id_does_not_match)
      end
    end

    def send_reimbursement_email
      Spree::ReimbursementMailer.reimbursement_email(id).deliver_later
    end

    def unpaid_amount_within_tolerance?
      reimbursement_count = reimbursement_models.count do |model|
        model.total_amount_reimbursed_for(self) > 0
      end
      leniency = if reimbursement_count > 0
                   (reimbursement_count - 1) * 0.01.to_d
                 else
                   0
                 end
      unpaid_amount.abs.between?(0, leniency)
    end
  end
end
