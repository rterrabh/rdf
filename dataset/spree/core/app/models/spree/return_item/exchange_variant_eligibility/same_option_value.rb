module Spree
  module ReturnItem::ExchangeVariantEligibility
    class SameOptionValue
      class_attribute :option_type_restrictions
      self.option_type_restrictions = []

      def self.eligible_variants(variant)
        product_variants = SameProduct.eligible_variants(variant).includes(option_values: :option_type)

        relevant_option_values = variant.option_values.select { |ov| option_type_restrictions.include? ov.option_type.name }
        if relevant_option_values.present?
          product_variants.select { |v| (relevant_option_values & v.option_values) == relevant_option_values }
        else
          product_variants
        end
      end
    end
  end
end
