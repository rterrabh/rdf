class UpgradeAdjustments < ActiveRecord::Migration
  def up
    #nodyna <class_eval-2545> <CE MODERATE (block execution)>
    Spree::Adjustment.class_eval do
      belongs_to :originator, polymorphic: true
    end
    Spree::Adjustment.where(:source_type => "Spree::Shipment").find_each do |adjustment|
      next if adjustment.source.nil?
      adjustment.source.update_column(:cost, adjustment.amount)
      adjustment.destroy!
    end

    Spree::Adjustment.where(:originator_type => "Spree::TaxRate").find_each do |adjustment|
      adjustment.source_id = adjustment.originator_id
      adjustment.source_type = "Spree::TaxRate"
      adjustment.save!
    end

    Spree::Adjustment.where(:originator_type => "Spree::PromotionAction").find_each do |adjustment|
      next if adjustment.originator.nil?
      adjustment.source = adjustment.originator
      begin
        if adjustment.source.calculator_type == "Spree::Calculator::FreeShipping"
          adjustment.source.becomes(Spree::Promotion::Actions::FreeShipping)
        end
      rescue
      end

      adjustment.save!
    end
  end
end
