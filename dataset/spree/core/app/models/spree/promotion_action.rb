module Spree
  class PromotionAction < Spree::Base
    acts_as_paranoid

    belongs_to :promotion, class_name: 'Spree::Promotion'

    scope :of_type, ->(t) { where(type: t) }

    def perform(options = {})
      raise 'perform should be implemented in a sub-class of PromotionAction'
    end

    protected

    def label(amount)
      "#{Spree.t(:promotion)} (#{promotion.name})"
    end
  end
end
