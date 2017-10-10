require 'active_support/duration'
require 'active_support/core_ext/time/calculations'
require 'active_support/core_ext/time/acts_like'

class Numeric
  def seconds
    ActiveSupport::Duration.new(self, [[:seconds, self]])
  end
  alias :second :seconds

  def minutes
    ActiveSupport::Duration.new(self * 60, [[:seconds, self * 60]])
  end
  alias :minute :minutes

  def hours
    ActiveSupport::Duration.new(self * 3600, [[:seconds, self * 3600]])
  end
  alias :hour :hours

  def days
    ActiveSupport::Duration.new(self * 24.hours, [[:days, self]])
  end
  alias :day :days

  def weeks
    ActiveSupport::Duration.new(self * 7.days, [[:days, self * 7]])
  end
  alias :week :weeks

  def fortnights
    ActiveSupport::Duration.new(self * 2.weeks, [[:days, self * 14]])
  end
  alias :fortnight :fortnights

  def in_milliseconds
    self * 1000
  end
end
