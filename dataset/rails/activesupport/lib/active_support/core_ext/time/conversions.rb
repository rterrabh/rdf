require 'active_support/inflector/methods'
require 'active_support/values/time_zone'

class Time
  DATE_FORMATS = {
    :db           => '%Y-%m-%d %H:%M:%S',
    :number       => '%Y%m%d%H%M%S',
    :nsec         => '%Y%m%d%H%M%S%9N',
    :time         => '%H:%M',
    :short        => '%d %b %H:%M',
    :long         => '%B %d, %Y %H:%M',
    :long_ordinal => lambda { |time|
      day_format = ActiveSupport::Inflector.ordinalize(time.day)
      time.strftime("%B #{day_format}, %Y %H:%M")
    },
    :rfc822       => lambda { |time|
      offset_format = time.formatted_offset(false)
      time.strftime("%a, %d %b %Y %H:%M:%S #{offset_format}")
    },
    :iso8601      => lambda { |time| time.iso8601 }
  }

  def to_formatted_s(format = :default)
    if formatter = DATE_FORMATS[format]
      formatter.respond_to?(:call) ? formatter.call(self).to_s : strftime(formatter)
    else
      to_default_s
    end
  end
  alias_method :to_default_s, :to_s
  alias_method :to_s, :to_formatted_s

  def formatted_offset(colon = true, alternate_utc_string = nil)
    utc? && alternate_utc_string || ActiveSupport::TimeZone.seconds_to_utc_offset(utc_offset, colon)
  end
end
