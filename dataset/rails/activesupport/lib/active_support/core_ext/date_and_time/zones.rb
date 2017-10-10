module DateAndTime
  module Zones
    def in_time_zone(zone = ::Time.zone)
      time_zone = ::Time.find_zone! zone
      time = acts_like?(:time) ? self : nil

      if time_zone
        time_with_zone(time, time_zone)
      else
        time || self.to_time
      end
    end

    private

    def time_with_zone(time, zone)
      if time
        ActiveSupport::TimeWithZone.new(time.utc? ? time : time.getutc, zone)
      else
        ActiveSupport::TimeWithZone.new(nil, zone, to_time(:utc))
      end
    end
  end
end

