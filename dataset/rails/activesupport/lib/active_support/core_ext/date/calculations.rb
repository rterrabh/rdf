require 'date'
require 'active_support/duration'
require 'active_support/core_ext/object/acts_like'
require 'active_support/core_ext/date/zones'
require 'active_support/core_ext/time/zones'
require 'active_support/core_ext/date_and_time/calculations'

class Date
  include DateAndTime::Calculations

  class << self
    attr_accessor :beginning_of_week_default

    def beginning_of_week
      Thread.current[:beginning_of_week] || beginning_of_week_default || :monday
    end

    def beginning_of_week=(week_start)
      Thread.current[:beginning_of_week] = find_beginning_of_week!(week_start)
    end

    def find_beginning_of_week!(week_start)
      raise ArgumentError, "Invalid beginning of week: #{week_start}" unless ::Date::DAYS_INTO_WEEK.key?(week_start)
      week_start
    end

    def yesterday
      ::Date.current.yesterday
    end

    def tomorrow
      ::Date.current.tomorrow
    end

    def current
      ::Time.zone ? ::Time.zone.today : ::Date.today
    end
  end

  def ago(seconds)
    in_time_zone.since(-seconds)
  end

  def since(seconds)
    in_time_zone.since(seconds)
  end
  alias :in :since

  def beginning_of_day
    in_time_zone
  end
  alias :midnight :beginning_of_day
  alias :at_midnight :beginning_of_day
  alias :at_beginning_of_day :beginning_of_day

  def middle_of_day
    in_time_zone.middle_of_day
  end
  alias :midday :middle_of_day
  alias :noon :middle_of_day
  alias :at_midday :middle_of_day
  alias :at_noon :middle_of_day
  alias :at_middle_of_day :middle_of_day

  def end_of_day
    in_time_zone.end_of_day
  end
  alias :at_end_of_day :end_of_day

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
      plus_with_duration(-other)
    else
      minus_without_duration(other)
    end
  end
  alias_method :minus_without_duration, :-
  alias_method :-, :minus_with_duration

  def advance(options)
    options = options.dup
    d = self
    d = d >> options.delete(:years) * 12 if options[:years]
    d = d >> options.delete(:months)     if options[:months]
    d = d +  options.delete(:weeks) * 7  if options[:weeks]
    d = d +  options.delete(:days)       if options[:days]
    d
  end

  def change(options)
    ::Date.new(
      options.fetch(:year, year),
      options.fetch(:month, month),
      options.fetch(:day, day)
    )
  end
  
  def compare_with_coercion(other)
    if other.is_a?(Time)
      self.to_datetime <=> other
    else
      compare_without_coercion(other)
    end
  end
  alias_method :compare_without_coercion, :<=>
  alias_method :<=>, :compare_with_coercion
end
