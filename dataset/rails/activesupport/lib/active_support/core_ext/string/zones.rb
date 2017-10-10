require 'active_support/core_ext/string/conversions'
require 'active_support/core_ext/time/zones'

class String
  def in_time_zone(zone = ::Time.zone)
    if zone
      ::Time.find_zone!(zone).parse(self)
    else
      to_time
    end
  end
end
