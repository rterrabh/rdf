module Spree
  class DefaultTaxZoneValidator < ActiveModel::Validator
    def validate(record)
      if record.included_in_price
        record.errors.add(:included_in_price, Spree.t(:included_price_validation)) unless Zone.default_tax
      end
    end
  end
end

module Spree
  class TaxRate < Spree::Base
    acts_as_paranoid

    include Spree::CalculatedAdjustments
    include Spree::AdjustmentSource

    belongs_to :zone, class_name: "Spree::Zone", inverse_of: :tax_rates
    belongs_to :tax_category, class_name: "Spree::TaxCategory", inverse_of: :tax_rates

    validates :amount, presence: true, numericality: true
    validates :tax_category_id, presence: true
    validates_with DefaultTaxZoneValidator

    scope :by_zone, ->(zone) { where(zone_id: zone) }

    def self.potential_rates_for_zone(zone)
      select("spree_tax_rates.*, spree_zones.default_tax").
        joins(:zone).
        merge(Spree::Zone.potential_matching_zones(zone)).
        order("spree_zones.default_tax DESC")
    end

    def self.match(order_tax_zone)
      return [] unless order_tax_zone

      potential_rates = potential_rates_for_zone(order_tax_zone)
      rates = potential_rates.includes(zone: { zone_members: :zoneable }).load.select do |rate|
        rate.potentially_applicable?(order_tax_zone)
      end

      rates.delete_if do |rate|
        rate.included_in_price? &&
        (rates - [rate]).map(&:tax_category).include?(rate.tax_category)
      end
    end

    def self.store_pre_tax_amount(item, rates)
      pre_tax_amount = case item
        when Spree::LineItem then item.discounted_amount
        when Spree::Shipment then item.discounted_cost
        end

      included_rates = rates.select(&:included_in_price)
      if included_rates.any?
        pre_tax_amount /= (1 + included_rates.map(&:amount).sum)
      end

      item.update_column(:pre_tax_amount, pre_tax_amount)
    end

    def self.adjust(order, items)
      rates = match(order.tax_zone)
      tax_categories = rates.map(&:tax_category)
      relevant_items, non_relevant_items = items.partition { |item| tax_categories.include?(item.tax_category) }
      Spree::Adjustment.where(adjustable: relevant_items).tax.destroy_all # using destroy_all to ensure adjustment destroy callback fires.
      relevant_items.each do |item|
        relevant_rates = rates.select { |rate| rate.tax_category == item.tax_category }
        store_pre_tax_amount(item, relevant_rates)
        relevant_rates.each do |rate|
          rate.adjust(order, item)
        end
      end
      non_relevant_items.each do |item|
        if item.adjustments.tax.present?
          item.adjustments.tax.destroy_all # using destroy_all to ensure adjustment destroy callback fires.
          item.update_columns pre_tax_amount: 0
        end
      end
    end

    def potentially_applicable?(order_tax_zone)
      self.zone == order_tax_zone ||
      self.zone.contains?(order_tax_zone) ||
      (self.included_in_price? && self.zone.default_tax)
    end

    def adjust(order, item)
      included = included_in_price && default_zone_or_zone_match?(order)
      create_adjustment(order, item, included)
    end

    def compute_amount(item)
      refund = included_in_price && !default_zone_or_zone_match?(item.order)
      compute(item) * (refund ? -1 : 1)
    end

    private

    def default_zone_or_zone_match?(order)
      Zone.default_tax.try(:contains?, order.tax_zone) || order.tax_zone == zone
    end

    def label(adjustment_amount)
      label = ""
      label << Spree.t(:refund) << ' ' if adjustment_amount < 0
      label << (name.present? ? name : tax_category.name) + " "
      label << (show_rate_in_label? ? "#{amount * 100}%" : "")
      label << " (#{Spree.t(:included_in_price)})" if included_in_price?
      label
    end
  end
end
