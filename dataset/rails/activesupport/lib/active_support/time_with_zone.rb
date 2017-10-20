require 'active_support/values/time_zone'
require 'active_support/core_ext/object/acts_like'

module ActiveSupport
  class TimeWithZone

    def self.name
      'Time'
    end

    include Comparable
    attr_reader :time_zone

    def initialize(utc_time, time_zone, local_time = nil, period = nil)
      @utc, @time_zone, @time = utc_time, time_zone, local_time
      @period = @utc ? period : get_period_and_ensure_valid_local_time(period)
    end

    def time
      @time ||= period.to_local(@utc)
    end

    def utc
      @utc ||= period.to_utc(@time)
    end
    alias_method :comparable_time, :utc
    alias_method :getgm, :utc
    alias_method :getutc, :utc
    alias_method :gmtime, :utc

    def period
      @period ||= time_zone.period_for_utc(@utc)
    end

    def in_time_zone(new_zone = ::Time.zone)
      return self if time_zone == new_zone
      utc.in_time_zone(new_zone)
    end

    def localtime(utc_offset = nil)
      utc.respond_to?(:getlocal) ? utc.getlocal(utc_offset) : utc.to_time.getlocal(utc_offset)
    end
    alias_method :getlocal, :localtime

    def dst?
      period.dst?
    end
    alias_method :isdst, :dst?

    def utc?
      time_zone.name == 'UTC'
    end
    alias_method :gmt?, :utc?

    def utc_offset
      period.utc_total_offset
    end
    alias_method :gmt_offset, :utc_offset
    alias_method :gmtoff, :utc_offset

    def formatted_offset(colon = true, alternate_utc_string = nil)
      utc? && alternate_utc_string || TimeZone.seconds_to_utc_offset(utc_offset, colon)
    end

    def zone
      period.zone_identifier.to_s
    end

    def inspect
      "#{time.strftime('%a, %d %b %Y %H:%M:%S')} #{zone} #{formatted_offset}"
    end

    def xmlschema(fraction_digits = 0)
      fraction = if fraction_digits.to_i > 0
        (".%06i" % time.usec)[0, fraction_digits.to_i + 1]
      end

      "#{time.strftime("%Y-%m-%dT%H:%M:%S")}#{fraction}#{formatted_offset(true, 'Z')}"
    end
    alias_method :iso8601, :xmlschema

    def as_json(options = nil)
      if ActiveSupport::JSON::Encoding.use_standard_json_time_format
        xmlschema(ActiveSupport::JSON::Encoding.time_precision)
      else
        %(#{time.strftime("%Y/%m/%d %H:%M:%S")} #{formatted_offset(false)})
      end
    end

    def encode_with(coder)
      if coder.respond_to?(:represent_object)
        coder.represent_object(nil, utc)
      else
        coder.represent_scalar(nil, utc.strftime("%Y-%m-%d %H:%M:%S.%9NZ"))
      end
    end

    def httpdate
      utc.httpdate
    end

    def rfc2822
      to_s(:rfc822)
    end
    alias_method :rfc822, :rfc2822

    def to_s(format = :default)
      if format == :db
        utc.to_s(format)
      elsif formatter = ::Time::DATE_FORMATS[format]
        formatter.respond_to?(:call) ? formatter.call(self).to_s : strftime(formatter)
      else
        "#{time.strftime("%Y-%m-%d %H:%M:%S")} #{formatted_offset(false, 'UTC')}" # mimicking Ruby 1.9 Time#to_s format
      end
    end
    alias_method :to_formatted_s, :to_s

    def strftime(format)
      format = format.gsub(/((?:\A|[^%])(?:%%)*)%Z/, "\\1#{zone}")
      getlocal(utc_offset).strftime(format)
    end

    def <=>(other)
      utc <=> other
    end

    def between?(min, max)
      utc.between?(min, max)
    end

    def past?
      utc.past?
    end

    def today?
      time.today?
    end

    def future?
      utc.future?
    end

    def eql?(other)
      utc.eql?(other)
    end

    def hash
      utc.hash
    end

    def +(other)
      if duration_of_variable_length?(other)
        method_missing(:+, other)
      else
        result = utc.acts_like?(:date) ? utc.since(other) : utc + other rescue utc.since(other)
        result.in_time_zone(time_zone)
      end
    end

    def -(other)
      if other.acts_like?(:time)
        to_time - other.to_time
      elsif duration_of_variable_length?(other)
        method_missing(:-, other)
      else
        result = utc.acts_like?(:date) ? utc.ago(other) : utc - other rescue utc.ago(other)
        result.in_time_zone(time_zone)
      end
    end

    def since(other)
      if duration_of_variable_length?(other)
        method_missing(:since, other)
      else
        utc.since(other).in_time_zone(time_zone)
      end
    end

    def ago(other)
      since(-other)
    end

    def advance(options)
      if options.values_at(:years, :weeks, :months, :days).any?
        method_missing(:advance, options)
      else
        utc.advance(options).in_time_zone(time_zone)
      end
    end

    %w(year mon month day mday wday yday hour min sec usec nsec to_date).each do |method_name|
      #nodyna <class_eval-1123> <CE MODERATE (define methods)>
      class_eval <<-EOV, __FILE__, __LINE__ + 1
        def #{method_name}    # def month
          time.#{method_name} #   time.month
        end                   # end
      EOV
    end

    def to_a
      [time.sec, time.min, time.hour, time.day, time.mon, time.year, time.wday, time.yday, dst?, zone]
    end

    def to_f
      utc.to_f
    end

    def to_i
      utc.to_i
    end
    alias_method :tv_sec, :to_i

    def to_r
      utc.to_r
    end

    def to_time
      utc.to_time
    end

    def to_datetime
      utc.to_datetime.new_offset(Rational(utc_offset, 86_400))
    end

    def acts_like_time?
      true
    end

    def is_a?(klass)
      klass == ::Time || super
    end
    alias_method :kind_of?, :is_a?

    def freeze
      period; utc; time # preload instance variables before freezing
      super
    end

    def marshal_dump
      [utc, time_zone.name, time]
    end

    def marshal_load(variables)
      initialize(variables[0].utc, ::Time.find_zone(variables[1]), variables[2].utc)
    end

    def respond_to?(sym, include_priv = false)
      return false if sym.to_sym == :to_str
      super
    end

    def respond_to_missing?(sym, include_priv)
      return false if sym.to_sym == :acts_like_date?
      time.respond_to?(sym, include_priv)
    end

    def method_missing(sym, *args, &block)
      wrap_with_time_zone time.__send__(sym, *args, &block)
    rescue NoMethodError => e
      raise e, e.message.sub(time.inspect, self.inspect), e.backtrace
    end

    private
      def get_period_and_ensure_valid_local_time(period)
        @time = transfer_time_values_to_utc_constructor(@time) unless @time.utc?
        begin
          period || @time_zone.period_for_local(@time)
        rescue ::TZInfo::PeriodNotFound
          @time += 1.hour
          retry
        end
      end

      def transfer_time_values_to_utc_constructor(time)
        ::Time.utc(time.year, time.month, time.day, time.hour, time.min, time.sec, Rational(time.nsec, 1000))
      end

      def duration_of_variable_length?(obj)
        ActiveSupport::Duration === obj && obj.parts.any? {|p| [:years, :months, :days].include?(p[0]) }
      end

      def wrap_with_time_zone(time)
        if time.acts_like?(:time)
          periods = time_zone.periods_for_local(time)
          self.class.new(nil, time_zone, time, periods.include?(period) ? period : nil)
        elsif time.is_a?(Range)
          wrap_with_time_zone(time.begin)..wrap_with_time_zone(time.end)
        else
          time
        end
      end
  end
end
