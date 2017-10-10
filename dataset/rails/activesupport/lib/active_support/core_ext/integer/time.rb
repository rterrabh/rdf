require 'active_support/duration'
require 'active_support/core_ext/numeric/time'

class Integer
  def months
    ActiveSupport::Duration.new(self * 30.days, [[:months, self]])
  end
  alias :month :months

  def years
    ActiveSupport::Duration.new(self * 365.25.days, [[:years, self]])
  end
  alias :year :years
end
