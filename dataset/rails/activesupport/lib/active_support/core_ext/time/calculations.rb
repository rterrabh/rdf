require 'active_support/duration'
require 'active_support/core_ext/time/conversions'
require 'active_support/time_with_zone'
require 'active_support/core_ext/time/zones'
require 'active_support/core_ext/date_and_time/calculations'

class Time
  include DateAndTime::Calculations

  COMMON_YEAR_DAYS_IN_MONTH = [nil, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

  class << self
    def ===(other)
      super || (self == Time && other.is_a?(ActiveSupport::TimeWithZone))
    end

    def days_in_month(month, year = now.year)
      if month == 2 && ::Date.gregorian_leap?(year)
        29
      else
        COMMON_YEAR_DAYS_IN_MONTH[month]
      end
    end

    def current
      ::Time.zone ? ::Time.zone.now : ::Time.now
    end

    def at_with_coercion(*args)
      return at_without_coercion(*args) if args.size != 1

      time_or_number = args.first

      if time_or_number.is_a?(ActiveSupport::TimeWithZone) || time_or_number.is_a?(DateTime)
        at_without_coercion(time_or_number.to_f).getlocal
      else
        at_without_coercion(time_or_number)
      end
    end
    alias_method :at_without_coercion, :at
    alias_method :at, :at_with_coercion
  end

  def seconds_since_midnight
    to_i - change(:hour => 0).to_i + (usec / 1.0e+6)
  end

  def seconds_until_end_of_day
    end_of_day.to_i - to_i
  end

  def change(options)
    new_year  = options.fetch(:year, year)
    new_month = options.fetch(:month, month)
    new_day   = options.fetch(:day, day)
    new_hour  = options.fetch(:hour, hour)
    new_min   = options.fetch(:min, options[:hour] ? 0 : min)
    new_sec   = options.fetch(:sec, (options[:hour] || options[:min]) ? 0 : sec)

    if new_nsec = options[:nsec]
      raise ArgumentError, "Can't change both :nsec and :usec at the same time: #{options.inspect}" if options[:usec]
      new_usec = Rational(new_nsec, 1000)
    else
      new_usec  = options.fetch(:usec, (options[:hour] || options[:min] || options[:sec]) ? 0 : Rational(nsec, 1000))
    end

    if utc?
      ::Time.utc(new_year, new_month, new_day, new_hour, new_min, new_sec, new_usec)
    elsif zone
      ::Time.local(new_year, new_month, new_day, new_hour, new_min, new_sec, new_usec)
    else
      raise ArgumentError, 'argument out of range' if new_usec >= 1000000
      ::Time.new(new_year, new_month, new_day, new_hour, new_min, new_sec + (new_usec.to_r / 1000000), utc_offset)
    end
  end

  def advance(options)
    unless options[:weeks].nil?
      options[:weeks], partial_weeks = options[:weeks].divmod(1)
      options[:days] = options.fetch(:days, 0) + 7 * partial_weeks
    end

    unless options[:days].nil?
      options[:days], partial_days = options[:days].divmod(1)
      options[:hours] = options.fetch(:hours, 0) + 24 * partial_days
    end

    d = to_date.advance(options)
    d = d.gregorian if d.julian?
    time_advanced_by_date = change(:year => d.year, :month => d.month, :day => d.day)
    seconds_to_advance = \
      options.fetch(:seconds, 0) +
      options.fetch(:minutes, 0) * 60 +
      options.fetch(:hours, 0) * 3600

    if seconds_to_advance.zero?
      time_advanced_by_date
    else
      time_advanced_by_date.since(seconds_to_advance)
    end
  end

  def ago(seconds)
    since(-seconds)
  end

  def since(seconds)
    self + seconds
  rescue
    to_datetime.since(seconds)
  end
  alias :in :since

  def beginning_of_day
    change(:hour => 0)
  end
  alias :midnight :beginning_of_day
  alias :at_midnight :beginning_of_day
  alias :at_beginning_of_day :beginning_of_day

  def middle_of_day
    change(:hour => 12)
  end
  alias :midday :middle_of_day
  alias :noon :middle_of_day
  alias :at_midday :middle_of_day
  alias :at_noon :middle_of_day
  alias :at_middle_of_day :middle_of_day

  def end_of_day
    change(
      :hour => 23,
      :min => 59,
      :sec => 59,
      :usec => Rational(999999999, 1000)
    )
  end
  alias :at_end_of_day :end_of_day

  def beginning_of_hour
    change(:min => 0)
  end
  alias :at_beginning_of_hour :beginning_of_hour

  def end_of_hour
    change(
      :min => 59,
      :sec => 59,
      :usec => Rational(999999999, 1000)
    )
  end
  alias :at_end_of_hour :end_of_hour

  def beginning_of_minute
    change(:sec => 0)
  end
  alias :at_beginning_of_minute :beginning_of_minute

  def end_of_minute
    change(
      :sec => 59,
      :usec => Rational(999999999, 1000)
    )
  end
  alias :at_end_of_minute :end_of_minute

  def all_day
    beginning_of_day..end_of_day
  end

  def plus_with_duration(other) #:nodoc:
    if ActiveSupport::Duration === other
      other.since(self)
    else
      plus_without_duration(other)
    end
  end
  alias_method :plus_without_duration, :+
  alias_method :+, :plus_with_duration

  def minus_with_duration(other) #:nodoc:
    if ActiveSupport::Duration === other
      other.until(self)
    else
      minus_without_duration(other)
    end
  end
  alias_method :minus_without_duration, :-
  alias_method :-, :minus_with_duration

  def minus_with_coercion(other)
    other = other.comparable_time if other.respond_to?(:comparable_time)
    other.is_a?(DateTime) ? to_f - other.to_f : minus_without_coercion(other)
  end
  alias_method :minus_without_coercion, :-
  alias_method :-, :minus_with_coercion

  def compare_with_coercion(other)
    if other.is_a?(Time)
      compare_without_coercion(other.to_time)
    else
      to_datetime <=> other
    end
  end
  alias_method :compare_without_coercion, :<=>
  alias_method :<=>, :compare_with_coercion

  def eql_with_coercion(other)
    other = other.comparable_time if other.respond_to?(:comparable_time)
    eql_without_coercion(other)
  end
  alias_method :eql_without_coercion, :eql?
  alias_method :eql?, :eql_with_coercion

end
