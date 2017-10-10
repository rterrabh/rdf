require 'active_support/core_ext/big_decimal/conversions'
require 'active_support/number_helper'

class Numeric

  def to_formatted_s(format = :default, options = {})
    case format
    when :phone
      return ActiveSupport::NumberHelper.number_to_phone(self, options)
    when :currency
      return ActiveSupport::NumberHelper.number_to_currency(self, options)
    when :percentage
      return ActiveSupport::NumberHelper.number_to_percentage(self, options)
    when :delimited
      return ActiveSupport::NumberHelper.number_to_delimited(self, options)
    when :rounded
      return ActiveSupport::NumberHelper.number_to_rounded(self, options)
    when :human
      return ActiveSupport::NumberHelper.number_to_human(self, options)
    when :human_size
      return ActiveSupport::NumberHelper.number_to_human_size(self, options)
    else
      self.to_default_s
    end
  end

  [Float, Fixnum, Bignum, BigDecimal].each do |klass|
    #nodyna <send-1054> <SD MODERATE (private methods)>
    klass.send(:alias_method, :to_default_s, :to_s)

    #nodyna <send-1055> <SD MODERATE (private methods)>
    #nodyna <define_method-1056> <DM MODERATE (array)>
    klass.send(:define_method, :to_s) do |*args|
      if args[0].is_a?(Symbol)
        format = args[0]
        options = args[1] || {}

        self.to_formatted_s(format, options)
      else
        to_default_s(*args)
      end
    end
  end
end
