class MigrateOldShippingCalculators < ActiveRecord::Migration
  def up
    Spree::ShippingMethod.all.each do |shipping_method|
      old_calculator = shipping_method.calculator
      next if old_calculator.class < Spree::ShippingCalculator # We don't want to mess with new shipping calculators
      #nodyna <eval-2547> <EV COMPLEX (class definition)>
      new_calculator = eval(old_calculator.class.name.sub("::Calculator::", "::Calculator::Shipping::")).new
      new_calculator.preferences.keys.each do |pref|
        pref_method = "preferred_#{pref}"
        #nodyna <send-2548> <SD COMPLEX (array)>
        #nodyna <send-2549> <SD COMPLEX (array)>
        new_calculator.send("#{pref_method}=", old_calculator.send(pref_method))
      end
      new_calculator.calculable = old_calculator.calculable
      new_calculator.save
    end
  end

  def down
  end
end
