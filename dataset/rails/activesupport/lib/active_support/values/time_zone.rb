require 'tzinfo'
require 'thread_safe'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/object/try'

module ActiveSupport
  class TimeZone
    MAPPING = {
      "International Date Line West" => "Pacific/Midway",
      "Midway Island"                => "Pacific/Midway",
      "American Samoa"               => "Pacific/Pago_Pago",
      "Hawaii"                       => "Pacific/Honolulu",
      "Alaska"                       => "America/Juneau",
      "Pacific Time (US & Canada)"   => "America/Los_Angeles",
      "Tijuana"                      => "America/Tijuana",
      "Mountain Time (US & Canada)"  => "America/Denver",
      "Arizona"                      => "America/Phoenix",
      "Chihuahua"                    => "America/Chihuahua",
      "Mazatlan"                     => "America/Mazatlan",
      "Central Time (US & Canada)"   => "America/Chicago",
      "Saskatchewan"                 => "America/Regina",
      "Guadalajara"                  => "America/Mexico_City",
      "Mexico City"                  => "America/Mexico_City",
      "Monterrey"                    => "America/Monterrey",
      "Central America"              => "America/Guatemala",
      "Eastern Time (US & Canada)"   => "America/New_York",
      "Indiana (East)"               => "America/Indiana/Indianapolis",
      "Bogota"                       => "America/Bogota",
      "Lima"                         => "America/Lima",
      "Quito"                        => "America/Lima",
      "Atlantic Time (Canada)"       => "America/Halifax",
      "Caracas"                      => "America/Caracas",
      "La Paz"                       => "America/La_Paz",
      "Santiago"                     => "America/Santiago",
      "Newfoundland"                 => "America/St_Johns",
      "Brasilia"                     => "America/Sao_Paulo",
      "Buenos Aires"                 => "America/Argentina/Buenos_Aires",
      "Montevideo"                   => "America/Montevideo",
      "Georgetown"                   => "America/Guyana",
      "Greenland"                    => "America/Godthab",
      "Mid-Atlantic"                 => "Atlantic/South_Georgia",
      "Azores"                       => "Atlantic/Azores",
      "Cape Verde Is."               => "Atlantic/Cape_Verde",
      "Dublin"                       => "Europe/Dublin",
      "Edinburgh"                    => "Europe/London",
      "Lisbon"                       => "Europe/Lisbon",
      "London"                       => "Europe/London",
      "Casablanca"                   => "Africa/Casablanca",
      "Monrovia"                     => "Africa/Monrovia",
      "UTC"                          => "Etc/UTC",
      "Belgrade"                     => "Europe/Belgrade",
      "Bratislava"                   => "Europe/Bratislava",
      "Budapest"                     => "Europe/Budapest",
      "Ljubljana"                    => "Europe/Ljubljana",
      "Prague"                       => "Europe/Prague",
      "Sarajevo"                     => "Europe/Sarajevo",
      "Skopje"                       => "Europe/Skopje",
      "Warsaw"                       => "Europe/Warsaw",
      "Zagreb"                       => "Europe/Zagreb",
      "Brussels"                     => "Europe/Brussels",
      "Copenhagen"                   => "Europe/Copenhagen",
      "Madrid"                       => "Europe/Madrid",
      "Paris"                        => "Europe/Paris",
      "Amsterdam"                    => "Europe/Amsterdam",
      "Berlin"                       => "Europe/Berlin",
      "Bern"                         => "Europe/Berlin",
      "Rome"                         => "Europe/Rome",
      "Stockholm"                    => "Europe/Stockholm",
      "Vienna"                       => "Europe/Vienna",
      "West Central Africa"          => "Africa/Algiers",
      "Bucharest"                    => "Europe/Bucharest",
      "Cairo"                        => "Africa/Cairo",
      "Helsinki"                     => "Europe/Helsinki",
      "Kyiv"                         => "Europe/Kiev",
      "Riga"                         => "Europe/Riga",
      "Sofia"                        => "Europe/Sofia",
      "Tallinn"                      => "Europe/Tallinn",
      "Vilnius"                      => "Europe/Vilnius",
      "Athens"                       => "Europe/Athens",
      "Istanbul"                     => "Europe/Istanbul",
      "Minsk"                        => "Europe/Minsk",
      "Jerusalem"                    => "Asia/Jerusalem",
      "Harare"                       => "Africa/Harare",
      "Pretoria"                     => "Africa/Johannesburg",
      "Kaliningrad"                  => "Europe/Kaliningrad",
      "Moscow"                       => "Europe/Moscow",
      "St. Petersburg"               => "Europe/Moscow",
      "Volgograd"                    => "Europe/Volgograd",
      "Samara"                       => "Europe/Samara",
      "Kuwait"                       => "Asia/Kuwait",
      "Riyadh"                       => "Asia/Riyadh",
      "Nairobi"                      => "Africa/Nairobi",
      "Baghdad"                      => "Asia/Baghdad",
      "Tehran"                       => "Asia/Tehran",
      "Abu Dhabi"                    => "Asia/Muscat",
      "Muscat"                       => "Asia/Muscat",
      "Baku"                         => "Asia/Baku",
      "Tbilisi"                      => "Asia/Tbilisi",
      "Yerevan"                      => "Asia/Yerevan",
      "Kabul"                        => "Asia/Kabul",
      "Ekaterinburg"                 => "Asia/Yekaterinburg",
      "Islamabad"                    => "Asia/Karachi",
      "Karachi"                      => "Asia/Karachi",
      "Tashkent"                     => "Asia/Tashkent",
      "Chennai"                      => "Asia/Kolkata",
      "Kolkata"                      => "Asia/Kolkata",
      "Mumbai"                       => "Asia/Kolkata",
      "New Delhi"                    => "Asia/Kolkata",
      "Kathmandu"                    => "Asia/Kathmandu",
      "Astana"                       => "Asia/Dhaka",
      "Dhaka"                        => "Asia/Dhaka",
      "Sri Jayawardenepura"          => "Asia/Colombo",
      "Almaty"                       => "Asia/Almaty",
      "Novosibirsk"                  => "Asia/Novosibirsk",
      "Rangoon"                      => "Asia/Rangoon",
      "Bangkok"                      => "Asia/Bangkok",
      "Hanoi"                        => "Asia/Bangkok",
      "Jakarta"                      => "Asia/Jakarta",
      "Krasnoyarsk"                  => "Asia/Krasnoyarsk",
      "Beijing"                      => "Asia/Shanghai",
      "Chongqing"                    => "Asia/Chongqing",
      "Hong Kong"                    => "Asia/Hong_Kong",
      "Urumqi"                       => "Asia/Urumqi",
      "Kuala Lumpur"                 => "Asia/Kuala_Lumpur",
      "Singapore"                    => "Asia/Singapore",
      "Taipei"                       => "Asia/Taipei",
      "Perth"                        => "Australia/Perth",
      "Irkutsk"                      => "Asia/Irkutsk",
      "Ulaanbaatar"                  => "Asia/Ulaanbaatar",
      "Seoul"                        => "Asia/Seoul",
      "Osaka"                        => "Asia/Tokyo",
      "Sapporo"                      => "Asia/Tokyo",
      "Tokyo"                        => "Asia/Tokyo",
      "Yakutsk"                      => "Asia/Yakutsk",
      "Darwin"                       => "Australia/Darwin",
      "Adelaide"                     => "Australia/Adelaide",
      "Canberra"                     => "Australia/Melbourne",
      "Melbourne"                    => "Australia/Melbourne",
      "Sydney"                       => "Australia/Sydney",
      "Brisbane"                     => "Australia/Brisbane",
      "Hobart"                       => "Australia/Hobart",
      "Vladivostok"                  => "Asia/Vladivostok",
      "Guam"                         => "Pacific/Guam",
      "Port Moresby"                 => "Pacific/Port_Moresby",
      "Magadan"                      => "Asia/Magadan",
      "Srednekolymsk"                => "Asia/Srednekolymsk",
      "Solomon Is."                  => "Pacific/Guadalcanal",
      "New Caledonia"                => "Pacific/Noumea",
      "Fiji"                         => "Pacific/Fiji",
      "Kamchatka"                    => "Asia/Kamchatka",
      "Marshall Is."                 => "Pacific/Majuro",
      "Auckland"                     => "Pacific/Auckland",
      "Wellington"                   => "Pacific/Auckland",
      "Nuku'alofa"                   => "Pacific/Tongatapu",
      "Tokelau Is."                  => "Pacific/Fakaofo",
      "Chatham Is."                  => "Pacific/Chatham",
      "Samoa"                        => "Pacific/Apia"
    }

    UTC_OFFSET_WITH_COLON = '%s%02d:%02d'
    UTC_OFFSET_WITHOUT_COLON = UTC_OFFSET_WITH_COLON.tr(':', '')

    @lazy_zones_map = ThreadSafe::Cache.new

    class << self
      def seconds_to_utc_offset(seconds, colon = true)
        format = colon ? UTC_OFFSET_WITH_COLON : UTC_OFFSET_WITHOUT_COLON
        sign = (seconds < 0 ? '-' : '+')
        hours = seconds.abs / 3600
        minutes = (seconds.abs % 3600) / 60
        format % [sign, hours, minutes]
      end

      def find_tzinfo(name)
        TZInfo::TimezoneProxy.new(MAPPING[name] || name)
      end

      alias_method :create, :new

      def new(name)
        self[name]
      end

      def all
        @zones ||= zones_map.values.sort
      end

      def zones_map #:nodoc:
        @zones_map ||= begin
          MAPPING.each_key {|place| self[place]} # load all the zones
          @lazy_zones_map
        end
      end

      def [](arg)
        case arg
          when String
          begin
            @lazy_zones_map[arg] ||= create(arg).tap { |tz| tz.utc_offset }
          rescue TZInfo::InvalidTimezoneIdentifier
            nil
          end
          when Numeric, ActiveSupport::Duration
            arg *= 3600 if arg.abs <= 13
            all.find { |z| z.utc_offset == arg.to_i }
          else
            raise ArgumentError, "invalid argument to TimeZone[]: #{arg.inspect}"
        end
      end

      def us_zones
        @us_zones ||= all.find_all { |z| z.name =~ /US|Arizona|Indiana|Hawaii|Alaska/ }
      end
    end

    include Comparable
    attr_reader :name
    attr_reader :tzinfo

    def initialize(name, utc_offset = nil, tzinfo = nil)
      @name = name
      @utc_offset = utc_offset
      @tzinfo = tzinfo || TimeZone.find_tzinfo(name)
      @current_period = nil
    end

    def utc_offset
      if @utc_offset
        @utc_offset
      else
        @current_period ||= tzinfo.current_period if tzinfo
        @current_period.utc_offset if @current_period
      end
    end

    def formatted_offset(colon=true, alternate_utc_string = nil)
      utc_offset == 0 && alternate_utc_string || self.class.seconds_to_utc_offset(utc_offset, colon)
    end

    def <=>(zone)
      return unless zone.respond_to? :utc_offset
      result = (utc_offset <=> zone.utc_offset)
      result = (name <=> zone.name) if result == 0
      result
    end

    def =~(re)
      re === name || re === MAPPING[name]
    end

    def to_s
      "(GMT#{formatted_offset}) #{name}"
    end

    def local(*args)
      time = Time.utc(*args)
      ActiveSupport::TimeWithZone.new(nil, self, time)
    end

    def at(secs)
      Time.at(secs).utc.in_time_zone(self)
    end

    def parse(str, now=now())
      parts = Date._parse(str, false)
      return if parts.empty?

      time = Time.new(
        parts.fetch(:year, now.year),
        parts.fetch(:mon, now.month),
        parts.fetch(:mday, parts[:year] || parts[:mon] ? 1 : now.day),
        parts.fetch(:hour, 0),
        parts.fetch(:min, 0),
        parts.fetch(:sec, 0) + parts.fetch(:sec_fraction, 0),
        parts.fetch(:offset, 0)
      )

      if parts[:offset]
        TimeWithZone.new(time.utc, self)
      else
        TimeWithZone.new(nil, self, time)
      end
    end

    def now
      time_now.utc.in_time_zone(self)
    end

    def today
      tzinfo.now.to_date
    end

    def tomorrow
      today + 1
    end

    def yesterday
      today - 1
    end

    def utc_to_local(time)
      tzinfo.utc_to_local(time)
    end

    def local_to_utc(time, dst=true)
      tzinfo.local_to_utc(time, dst)
    end

    def period_for_utc(time)
      tzinfo.period_for_utc(time)
    end

    def period_for_local(time, dst=true)
      tzinfo.period_for_local(time, dst)
    end

    def periods_for_local(time) #:nodoc:
      tzinfo.periods_for_local(time)
    end

    private
      def time_now
        Time.now
      end
  end
end
