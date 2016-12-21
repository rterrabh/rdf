class MigrateOldShippingCalculators < ActiveRecord::Migration
  def up
    Spree::ShippingMethod.all.each do |shipping_method|
      old_calculator = shipping_method.calculator
      next if old_calculator.class < Spree::ShippingCalculator # We don't want to mess with new shipping calculators
      #nodyna <ID:eval-42> <eval VERY HIGH ex5>
      new_calculator = eval(old_calculator.class.name.sub("::Calculator::", "::Calculator::Shipping::")).new
      new_calculator.preferences.keys.each do |pref|
        # Preferences can't be read/set by name, you have to prefix preferred_
        pref_method = "preferred_#{pref}"
        #nodyna <ID:send-22> <send VERY HIGH ex2>
        #nodyna <ID:send-22> <send VERY HIGH ex2>
        new_calculator.send("#{pref_method}=", old_calculator.send(pref_method))
      end
      new_calculator.calculable = old_calculator.calculable
      new_calculator.save
    end
  end

  def down
  end
end
