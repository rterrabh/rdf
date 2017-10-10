require "date"

module XMLRPC # :nodoc:

class DateTime

  attr_reader :year, :month, :day, :hour, :min, :sec

  def year= (value)
    raise ArgumentError, "date/time out of range" unless value.is_a? Integer
    @year = value
  end

  def month= (value)
    raise ArgumentError, "date/time out of range" unless (1..12).include? value
    @month = value
  end

  def day= (value)
    raise ArgumentError, "date/time out of range" unless (1..31).include? value
    @day = value
  end

  def hour= (value)
    raise ArgumentError, "date/time out of range" unless (0..24).include? value
    @hour = value
  end

  def min= (value)
    raise ArgumentError, "date/time out of range" unless (0..59).include? value
    @min = value
  end

  def sec= (value)
    raise ArgumentError, "date/time out of range" unless (0..59).include? value
    @sec = value
  end

  alias mon  month
  alias mon= month=


  def initialize(year, month, day, hour, min, sec)
    self.year, self.month, self.day = year, month, day
    self.hour, self.min, self.sec   = hour, min, sec
  end

  def to_time
    if @year >= 1970
      Time.gm(*to_a)
    else
      nil
    end
  end

  def to_date
    Date.new(*to_a[0,3])
  end

  def to_a
    [@year, @month, @day, @hour, @min, @sec]
  end

  def ==(o)
    self.to_a == Array(o) rescue false
  end

end


end # module XMLRPC


=begin
= History
    $Id$
=end
