require 'drb/drb'
require 'thread'


module Rinda


  class RindaError < RuntimeError; end


  class InvalidHashTupleKey < RindaError; end


  class RequestCanceledError < ThreadError; end


  class RequestExpiredError < ThreadError; end


  class Tuple


    def initialize(ary_or_hash)
      if hash?(ary_or_hash)
        init_with_hash(ary_or_hash)
      else
        init_with_ary(ary_or_hash)
      end
    end


    def size
      @tuple.size
    end


    def [](k)
      @tuple[k]
    end


    def fetch(k)
      @tuple.fetch(k)
    end


    def each # FIXME
      if Hash === @tuple
        @tuple.each { |k, v| yield(k, v) }
      else
        @tuple.each_with_index { |v, k| yield(k, v) }
      end
    end

    def value
      @tuple
    end

    private

    def hash?(ary_or_hash)
      ary_or_hash.respond_to?(:keys)
    end


    def init_with_ary(ary)
      @tuple = Array.new(ary.size)
      @tuple.size.times do |i|
        @tuple[i] = ary[i]
      end
    end


    def init_with_hash(hash)
      @tuple = Hash.new
      hash.each do |k, v|
        raise InvalidHashTupleKey unless String === k
        @tuple[k] = v
      end
    end

  end


  class Template < Tuple


    def match(tuple)
      return false unless tuple.respond_to?(:size)
      return false unless tuple.respond_to?(:fetch)
      return false unless self.size == tuple.size
      each do |k, v|
        begin
          it = tuple.fetch(k)
        rescue
          return false
        end
        next if v.nil?
        next if v == it
        next if v === it
        return false
      end
      return true
    end


    def ===(tuple)
      match(tuple)
    end

  end


  class DRbObjectTemplate


    def initialize(uri=nil, ref=nil)
      @drb_uri = uri
      @drb_ref = ref
    end


    def ===(ro)
      return true if super(ro)
      unless @drb_uri.nil?
        return false unless (@drb_uri === ro.__drburi rescue false)
      end
      unless @drb_ref.nil?
        return false unless (@drb_ref === ro.__drbref rescue false)
      end
      true
    end

  end


  class TupleSpaceProxy

    class Port # :nodoc:
      attr_reader :value

      def self.deliver
        port = new

        begin
          yield(port)
        ensure
          port.close
        end

        port.value
      end

      def initialize
        @open = true
        @value = nil
      end


      def close
        @open = false
      end


      def push value
        raise 'port closed' unless @open

        @value = value

        nil # avoid Marshal
      end
    end


    def initialize(ts)
      @ts = ts
    end


    def write(tuple, sec=nil)
      @ts.write(tuple, sec)
    end


    def take(tuple, sec=nil, &block)
      Port.deliver do |port|
        @ts.move(DRbObject.new(port), tuple, sec, &block)
      end
    end


    def read(tuple, sec=nil, &block)
      @ts.read(tuple, sec, &block)
    end


    def read_all(tuple)
      @ts.read_all(tuple)
    end


    def notify(ev, tuple, sec=nil)
      @ts.notify(ev, tuple, sec)
    end

  end


  class SimpleRenewer

    include DRbUndumped


    def initialize(sec=180)
      @sec = sec
    end


    def renew
      @sec
    end
  end

end

