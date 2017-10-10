require 'date'
require 'active_support/inflector/methods'
require 'active_support/core_ext/date/zones'
require 'active_support/core_ext/module/remove_method'

class Date
  DATE_FORMATS = {
    :short        => '%e %b',
    :long         => '%B %e, %Y',
    :db           => '%Y-%m-%d',
    :number       => '%Y%m%d',
    :long_ordinal => lambda { |date|
      day_format = ActiveSupport::Inflector.ordinalize(date.day)
      date.strftime("%B #{day_format}, %Y") # => "April 25th, 2007"
    },
    :rfc822       => '%e %b %Y',
    :iso8601      => lambda { |date| date.iso8601 }
  }

  remove_method :to_time

  remove_possible_method :xmlschema

  def to_formatted_s(format = :default)
    if formatter = DATE_FORMATS[format]
      if formatter.respond_to?(:call)
        formatter.call(self).to_s
      else
        strftime(formatter)
      end
    else
      to_default_s
    end
  end
  alias_method :to_default_s, :to_s
  alias_method :to_s, :to_formatted_s

  def readable_inspect
    strftime('%a, %d %b %Y')
  end
  alias_method :default_inspect, :inspect
  alias_method :inspect, :readable_inspect

  def to_time(form = :local)
    #nodyna <send-1053> <SD COMPLEX (change-prone variables)>
    ::Time.send(form, year, month, day)
  end

  def xmlschema
    in_time_zone.xmlschema
  end
end
