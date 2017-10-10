module Spree

  class ReimbursementPerformer

    class << self
      class_attribute :reimbursement_type_engine
      self.reimbursement_type_engine = Spree::Reimbursement::ReimbursementTypeEngine

      def simulate(reimbursement)
        execute(reimbursement, true)
      end

      def perform(reimbursement)
        execute(reimbursement, false)
      end

      private

      def execute(reimbursement, simulate)
        reimbursement_type_hash = calculate_reimbursement_types(reimbursement)

        reimbursement_type_hash.flat_map do |reimbursement_type, return_items|
          reimbursement_type.reimburse(reimbursement, return_items, simulate)
        end
      end

      def calculate_reimbursement_types(reimbursement)
        reimbursement_type_engine.new(reimbursement.return_items).calculate_reimbursement_types
      end

    end

  end

end
