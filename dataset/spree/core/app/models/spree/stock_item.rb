module Spree
  class StockItem < Spree::Base
    acts_as_paranoid

    belongs_to :stock_location, class_name: 'Spree::StockLocation', inverse_of: :stock_items
    belongs_to :variant, class_name: 'Spree::Variant', inverse_of: :stock_items, counter_cache: true
    has_many :stock_movements, inverse_of: :stock_item

    validates_presence_of :stock_location, :variant
    validates_uniqueness_of :variant_id, scope: [:stock_location_id, :deleted_at]

    validates_numericality_of :count_on_hand,
                              greater_than_or_equal_to: 0,
                              less_than_or_equal_to: 2**31 - 1,
                              only_integer: true, if: :verify_count_on_hand?

    delegate :weight, :should_track_inventory?, to: :variant

    after_save :conditional_variant_touch, if: :changed?
    after_touch { variant.touch }

    self.whitelisted_ransackable_attributes = ['count_on_hand', 'stock_location_id']

    def backordered_inventory_units
      Spree::InventoryUnit.backordered_for_stock_item(self)
    end

    def variant_name
      variant.name
    end

    def adjust_count_on_hand(value)
      self.with_lock do
        self.count_on_hand = self.count_on_hand + value
        process_backorders(count_on_hand - count_on_hand_was)

        self.save!
      end
    end

    def set_count_on_hand(value)
      self.count_on_hand = value
      process_backorders(count_on_hand - count_on_hand_was)

      self.save!
    end

    def in_stock?
      self.count_on_hand > 0
    end

    # Tells whether it's available to be included in a shipment
    def available?
      self.in_stock? || self.backorderable?
    end

    def variant
      Spree::Variant.unscoped { super }
    end

    def reduce_count_on_hand_to_zero
      self.set_count_on_hand(0) if count_on_hand > 0
    end

    private
      def verify_count_on_hand?
        count_on_hand_changed? && !backorderable? && (count_on_hand < count_on_hand_was) && (count_on_hand < 0)
      end

      def count_on_hand=(value)
        write_attribute(:count_on_hand, value)
      end

      # Process backorders based on amount of stock received
      # If stock was -20 and is now -15 (increase of 5 units), then we should process 5 inventory orders.
      # If stock was -20 but then was -25 (decrease of 5 units), do nothing.
      def process_backorders(number)
        if number > 0
          backordered_inventory_units.first(number).each do |unit|
            unit.fill_backorder
          end
        end
      end

      def conditional_variant_touch
        # the variant_id changes from nil when a new stock location is added
        stock_changed = (count_on_hand_changed? && count_on_hand_change.any?(&:zero?)) || variant_id_changed?

        if !Spree::Config.binary_inventory_cache || stock_changed
          variant.touch
        end
      end
  end
end
