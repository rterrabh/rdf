require 'date'
require 'active_support/inflector/methods'
require 'active_support/core_ext/time/conversions'
require 'active_support/core_ext/date_time/calculations'
require 'active_support/values/time_zone'

class DateTime
  def to_formatted_s(format = :default)
    if formatter = ::Time::DATE_FORMATS[format]
      formatter.respond_to?(:call) ? formatter.call(self).to_s : strftime(formatter)
    else
      to_default_s
    end
  end
  alias_method :to_default_s, :to_s if instance_methods(false).include?(:to_s)
  alias_method :to_s, :to_formatted_s

  def formatted_offset(colon = true, alternate_utc_string = nil)
    utc? && alternate_utc_string || ActiveSupport::TimeZone.seconds_to_utc_offset(utc_offset, colon)
  end

  def readable_inspect
    to_s(:rfc822)
  end
  alias_method :default_inspect, :inspect
  alias_method :inspect, :readable_inspect

  def self.civil_from_format(utc_or_local, year, month=1, day=1, hour=0, min=0, sec=0)
    if utc_or_local.to_sym == :local
      offset = ::Time.local(year, month, day).utc_offset.to_r / 86400
    else
      offset = 0
    end
    civil(year, month, day, hour, min, sec, offset)
  end

  def to_f
    seconds_since_unix_epoch.to_f + sec_fraction
  end

  def to_i
    seconds_since_unix_epoch.to_i
  end

  def usec
    (sec_fraction * 1_000_000).to_i
  end

  def nsec
    (sec_fraction * 1_000_000_000).to_i
  end

  private

  def offset_in_seconds
    (offset * 86400).to_i
  end

  def seconds_since_unix_epoch
    (jd - 2440588) * 86400 - offset_in_seconds + seconds_since_midnight
  end
end
