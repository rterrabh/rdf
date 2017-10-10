require 'active_support/time_with_zone'
require 'active_support/core_ext/time/acts_like'
require 'active_support/core_ext/date_and_time/zones'

class Time
  include DateAndTime::Zones
  class << self
    attr_accessor :zone_default

    def zone
      Thread.current[:time_zone] || zone_default
    end

    def zone=(time_zone)
      Thread.current[:time_zone] = find_zone!(time_zone)
    end

    def use_zone(time_zone)
      new_zone = find_zone!(time_zone)
      begin
        old_zone, ::Time.zone = ::Time.zone, new_zone
        yield
      ensure
        ::Time.zone = old_zone
      end
    end

    def find_zone!(time_zone)
      if !time_zone || time_zone.is_a?(ActiveSupport::TimeZone)
        time_zone
      else
        unless time_zone.respond_to?(:period_for_local)
          time_zone = ActiveSupport::TimeZone[time_zone] || TZInfo::Timezone.get(time_zone)
        end

        if time_zone.is_a?(ActiveSupport::TimeZone)
          time_zone
        else
          ActiveSupport::TimeZone.create(time_zone.name, nil, time_zone)
        end
      end
    rescue TZInfo::InvalidTimezoneIdentifier
      raise ArgumentError, "Invalid Timezone: #{time_zone}"
    end

    def find_zone(time_zone)
      find_zone!(time_zone) rescue nil
    end
  end
end
