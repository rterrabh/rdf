require 'active_support/core_ext/array/conversions'
require 'active_support/core_ext/object/acts_like'

module ActiveSupport
  class Duration
    attr_accessor :value, :parts

    def initialize(value, parts) #:nodoc:
      @value, @parts = value, parts
    end

    def +(other)
      if Duration === other
        Duration.new(value + other.value, @parts + other.parts)
      else
        Duration.new(value + other, @parts + [[:seconds, other]])
      end
    end

    def -(other)
      self + (-other)
    end

    def -@ #:nodoc:
      Duration.new(-value, parts.map { |type,number| [type, -number] })
    end

    def is_a?(klass) #:nodoc:
      Duration == klass || value.is_a?(klass)
    end
    alias :kind_of? :is_a?

    def instance_of?(klass) # :nodoc:
      Duration == klass || value.instance_of?(klass)
    end

    def ==(other)
      if Duration === other
        other.value == value
      else
        other == value
      end
    end

    def to_s
      @value.to_s
    end

    def to_i
      @value.to_i
    end

    def eql?(other)
      Duration === other && other.value.eql?(value)
    end

    def hash
      @value.hash
    end

    def self.===(other) #:nodoc:
      other.is_a?(Duration)
    rescue ::NoMethodError
      false
    end

    def since(time = ::Time.current)
      sum(1, time)
    end
    alias :from_now :since

    def ago(time = ::Time.current)
      sum(-1, time)
    end
    alias :until :ago

    def inspect #:nodoc:
      parts.
        reduce(::Hash.new(0)) { |h,(l,r)| h[l] += r; h }.
        sort_by {|unit,  _ | [:years, :months, :days, :minutes, :seconds].index(unit)}.
        map     {|unit, val| "#{val} #{val == 1 ? unit.to_s.chop : unit.to_s}"}.
        to_sentence(locale: ::I18n.default_locale)
    end

    def as_json(options = nil) #:nodoc:
      to_i
    end

    def respond_to_missing?(method, include_private=false) #:nodoc
      @value.respond_to?(method, include_private)
    end

    delegate :<=>, to: :value

    protected

      def sum(sign, time = ::Time.current) #:nodoc:
        parts.inject(time) do |t,(type,number)|
          if t.acts_like?(:time) || t.acts_like?(:date)
            if type == :seconds
              t.since(sign * number)
            else
              t.advance(type => sign * number)
            end
          else
            raise ::ArgumentError, "expected a time or date, got #{time.inspect}"
          end
        end
      end

    private

      def ===(other) #:nodoc:
        value === other
      end

      def method_missing(method, *args, &block) #:nodoc:
        #nodyna <send-1109> <SD COMPLEX (change-prone variables)>
        value.send(method, *args, &block)
      end
  end
end
