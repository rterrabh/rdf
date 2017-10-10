require 'date'
require 'active_support/core_ext/time/calculations'

class String
  def to_time(form = :local)
    parts = Date._parse(self, false)
    return if parts.empty?

    now = Time.now
    time = Time.new(
      parts.fetch(:year, now.year),
      parts.fetch(:mon, now.month),
      parts.fetch(:mday, now.day),
      parts.fetch(:hour, 0),
      parts.fetch(:min, 0),
      parts.fetch(:sec, 0) + parts.fetch(:sec_fraction, 0),
      parts.fetch(:offset, form == :utc ? 0 : nil)
    )

    form == :utc ? time.utc : time.getlocal
  end

  def to_date
    ::Date.parse(self, false) unless blank?
  end

  def to_datetime
    ::DateTime.parse(self, false) unless blank?
  end
end
