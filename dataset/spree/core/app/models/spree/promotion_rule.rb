module Spree
  class PromotionRule < Spree::Base
    belongs_to :promotion, class_name: 'Spree::Promotion', inverse_of: :promotion_rules

    scope :of_type, ->(t) { where(type: t) }

    validate :unique_per_promotion, on: :create

    def self.for(promotable)
      all.select { |rule| rule.applicable?(promotable) }
    end

    def applicable?(promotable)
      raise 'applicable? should be implemented in a sub-class of Spree::PromotionRule'
    end

    def eligible?(promotable, options = {})
      raise 'eligible? should be implemented in a sub-class of Spree::PromotionRule'
    end

    def actionable?(line_item)
      true
    end

    def eligibility_errors
      @eligibility_errors ||= ActiveModel::Errors.new(self)
    end

    private
    def unique_per_promotion
      if Spree::PromotionRule.exists?(promotion_id: promotion_id, type: self.class.name)
        errors[:base] << "Promotion already contains this rule type"
      end
    end

    def eligibility_error_message(key, options = {})
      Spree.t(key, Hash[scope: [:eligibility_errors, :messages]].merge(options))
    end
  end
end
