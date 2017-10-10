require 'date'

class DateTime
  class << self
    def current
      ::Time.zone ? ::Time.zone.now.to_datetime : ::Time.now.to_datetime
    end
  end

  def seconds_since_midnight
    sec + (min * 60) + (hour * 3600)
  end

  def seconds_until_end_of_day
    end_of_day.to_i - to_i
  end

  def change(options)
    ::DateTime.civil(
      options.fetch(:year, year),
      options.fetch(:month, month),
      options.fetch(:day, day),
      options.fetch(:hour, hour),
      options.fetch(:min, options[:hour] ? 0 : min),
      options.fetch(:sec, (options[:hour] || options[:min]) ? 0 : sec + sec_fraction),
      options.fetch(:offset, offset),
      options.fetch(:start, start)
    )
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
    datetime_advanced_by_date = change(:year => d.year, :month => d.month, :day => d.day)
    seconds_to_advance = \
      options.fetch(:seconds, 0) +
      options.fetch(:minutes, 0) * 60 +
      options.fetch(:hours, 0) * 3600

    if seconds_to_advance.zero?
      datetime_advanced_by_date
    else
      datetime_advanced_by_date.since(seconds_to_advance)
    end
  end

  def ago(seconds)
    since(-seconds)
  end

  def since(seconds)
    self + Rational(seconds.round, 86400)
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
    change(:hour => 23, :min => 59, :sec => 59)
  end
  alias :at_end_of_day :end_of_day

  def beginning_of_hour
    change(:min => 0)
  end
  alias :at_beginning_of_hour :beginning_of_hour

  def end_of_hour
    change(:min => 59, :sec => 59)
  end
  alias :at_end_of_hour :end_of_hour

  def beginning_of_minute
    change(:sec => 0)
  end
  alias :at_beginning_of_minute :beginning_of_minute

  def end_of_minute
    change(:sec => 59)
  end
  alias :at_end_of_minute :end_of_minute

  def utc
    new_offset(0)
  end
  alias_method :getutc, :utc

  def utc?
    offset == 0
  end

  def utc_offset
    (offset * 86400).to_i
  end

  def <=>(other)
    if other.kind_of?(Infinity)
      super
    elsif other.respond_to? :to_datetime
      super other.to_datetime rescue nil
    else
      nil
    end
  end

end
