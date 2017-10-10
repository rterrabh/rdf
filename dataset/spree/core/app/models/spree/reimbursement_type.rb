module Spree
  class ReimbursementType < Spree::Base
    include Spree::NamedType

    ORIGINAL = 'original'

    has_many :return_items

    def self.reimburse(reimbursement, return_items, simulate)
      raise "Implement me"
    end
  end
end
