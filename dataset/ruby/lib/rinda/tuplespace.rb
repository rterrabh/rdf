require 'monitor'
require 'thread'
require 'drb/drb'
require 'rinda/rinda'
require 'enumerator'
require 'forwardable'

module Rinda


  class TupleEntry

    include DRbUndumped

    attr_accessor :expires


    def initialize(ary, sec=nil)
      @cancel = false
      @expires = nil
      @tuple = make_tuple(ary)
      @renewer = nil
      renew(sec)
    end


    def cancel
      @cancel = true
    end


    def alive?
      !canceled? && !expired?
    end


    def value; @tuple.value; end


    def canceled?; @cancel; end


    def expired?
      return true unless @expires
      return false if @expires > Time.now
      return true if @renewer.nil?
      renew(@renewer)
      return true unless @expires
      return @expires < Time.now
    end


    def renew(sec_or_renewer)
      sec, @renewer = get_renewer(sec_or_renewer)
      @expires = make_expires(sec)
    end


    def make_expires(sec=nil)
      case sec
      when Numeric
        Time.now + sec
      when true
        Time.at(1)
      when nil
        Time.at(2**31-1)
      end
    end


    def [](key)
      @tuple[key]
    end


    def fetch(key)
      @tuple.fetch(key)
    end


    def size
      @tuple.size
    end


    def make_tuple(ary)
      Rinda::Tuple.new(ary)
    end

    private


    def get_renewer(it)
      case it
      when Numeric, true, nil
        return it, nil
      else
        begin
          return it.renew, it
        rescue Exception
          return it, nil
        end
      end
    end

  end


  class TemplateEntry < TupleEntry

    def match(tuple)
      @tuple.match(tuple)
    end

    alias === match

    def make_tuple(ary) # :nodoc:
      Rinda::Template.new(ary)
    end

  end


  class WaitTemplateEntry < TemplateEntry

    attr_reader :found

    def initialize(place, ary, expires=nil)
      super(ary, expires)
      @place = place
      @cond = place.new_cond
      @found = nil
    end

    def cancel
      super
      signal
    end

    def wait
      @cond.wait
    end

    def read(tuple)
      @found = tuple
      signal
    end

    def signal
      @place.synchronize do
        @cond.signal
      end
    end

  end


  class NotifyTemplateEntry < TemplateEntry


    def initialize(place, event, tuple, expires=nil)
      ary = [event, Rinda::Template.new(tuple)]
      super(ary, expires)
      @queue = Queue.new
      @done = false
    end


    def notify(ev)
      @queue.push(ev)
    end


    def pop
      raise RequestExpiredError if @done
      it = @queue.pop
      @done = true if it[0] == 'close'
      return it
    end


    def each # :yields: event, tuple
      while !@done
        it = pop
        yield(it)
      end
    rescue
    ensure
      cancel
    end

  end


  class TupleBag
    class TupleBin
      extend Forwardable
      def_delegators '@bin', :find_all, :delete_if, :each, :empty?

      def initialize
        @bin = []
      end

      def add(tuple)
        @bin.push(tuple)
      end

      def delete(tuple)
        idx = @bin.rindex(tuple)
        @bin.delete_at(idx) if idx
      end

      def find
        @bin.reverse_each do |x|
          return x if yield(x)
        end
        nil
      end
    end

    def initialize # :nodoc:
      @hash = {}
      @enum = enum_for(:each_entry)
    end


    def has_expires?
      @enum.find do |tuple|
        tuple.expires
      end
    end


    def push(tuple)
      key = bin_key(tuple)
      @hash[key] ||= TupleBin.new
      @hash[key].add(tuple)
    end


    def delete(tuple)
      key = bin_key(tuple)
      bin = @hash[key]
      return nil unless bin
      bin.delete(tuple)
      @hash.delete(key) if bin.empty?
      tuple
    end

    def find_all(template)
      bin_for_find(template).find_all do |tuple|
        tuple.alive? && template.match(tuple)
      end
    end


    def find(template)
      bin_for_find(template).find do |tuple|
        tuple.alive? && template.match(tuple)
      end
    end


    def find_all_template(tuple)
      @enum.find_all do |template|
        template.alive? && template.match(tuple)
      end
    end


    def delete_unless_alive
      deleted = []
      @hash.each do |key, bin|
        bin.delete_if do |tuple|
          if tuple.alive?
            false
          else
            deleted.push(tuple)
            true
          end
        end
      end
      deleted
    end

    private
    def each_entry(&blk)
      @hash.each do |k, v|
        v.each(&blk)
      end
    end

    def bin_key(tuple)
      head = tuple[0]
      if head.class == Symbol
        return head
      else
        false
      end
    end

    def bin_for_find(template)
      key = bin_key(template)
      key ? @hash.fetch(key, []) : @enum
    end
  end


  class TupleSpace

    include DRbUndumped
    include MonitorMixin


    def initialize(period=60)
      super()
      @bag = TupleBag.new
      @read_waiter = TupleBag.new
      @take_waiter = TupleBag.new
      @notify_waiter = TupleBag.new
      @period = period
      @keeper = nil
    end


    def write(tuple, sec=nil)
      entry = create_entry(tuple, sec)
      synchronize do
        if entry.expired?
          @read_waiter.find_all_template(entry).each do |template|
            template.read(tuple)
          end
          notify_event('write', entry.value)
          notify_event('delete', entry.value)
        else
          @bag.push(entry)
          start_keeper if entry.expires
          @read_waiter.find_all_template(entry).each do |template|
            template.read(tuple)
          end
          @take_waiter.find_all_template(entry).each do |template|
            template.signal
          end
          notify_event('write', entry.value)
        end
      end
      entry
    end


    def take(tuple, sec=nil, &block)
      move(nil, tuple, sec, &block)
    end


    def move(port, tuple, sec=nil)
      template = WaitTemplateEntry.new(self, tuple, sec)
      yield(template) if block_given?
      synchronize do
        entry = @bag.find(template)
        if entry
          port.push(entry.value) if port
          @bag.delete(entry)
          notify_event('take', entry.value)
          return port ? nil : entry.value
        end
        raise RequestExpiredError if template.expired?

        begin
          @take_waiter.push(template)
          start_keeper if template.expires
          while true
            raise RequestCanceledError if template.canceled?
            raise RequestExpiredError if template.expired?
            entry = @bag.find(template)
            if entry
              port.push(entry.value) if port
              @bag.delete(entry)
              notify_event('take', entry.value)
              return port ? nil : entry.value
            end
            template.wait
          end
        ensure
          @take_waiter.delete(template)
        end
      end
    end


    def read(tuple, sec=nil)
      template = WaitTemplateEntry.new(self, tuple, sec)
      yield(template) if block_given?
      synchronize do
        entry = @bag.find(template)
        return entry.value if entry
        raise RequestExpiredError if template.expired?

        begin
          @read_waiter.push(template)
          start_keeper if template.expires
          template.wait
          raise RequestCanceledError if template.canceled?
          raise RequestExpiredError if template.expired?
          return template.found
        ensure
          @read_waiter.delete(template)
        end
      end
    end


    def read_all(tuple)
      template = WaitTemplateEntry.new(self, tuple, nil)
      synchronize do
        entry = @bag.find_all(template)
        entry.collect do |e|
          e.value
        end
      end
    end


    def notify(event, tuple, sec=nil)
      template = NotifyTemplateEntry.new(self, event, tuple, sec)
      synchronize do
        @notify_waiter.push(template)
      end
      template
    end

    private

    def create_entry(tuple, sec)
      TupleEntry.new(tuple, sec)
    end


    def keep_clean
      synchronize do
        @read_waiter.delete_unless_alive.each do |e|
          e.signal
        end
        @take_waiter.delete_unless_alive.each do |e|
          e.signal
        end
        @notify_waiter.delete_unless_alive.each do |e|
          e.notify(['close'])
        end
        @bag.delete_unless_alive.each do |e|
          notify_event('delete', e.value)
        end
      end
    end


    def notify_event(event, tuple)
      ev = [event, tuple]
      @notify_waiter.find_all_template(ev).each do |template|
        template.notify(ev)
      end
    end


    def start_keeper
      return if @keeper && @keeper.alive?
      @keeper = Thread.new do
        while true
          sleep(@period)
          synchronize do
            break unless need_keeper?
            keep_clean
          end
        end
      end
    end


    def need_keeper?
      return true if @bag.has_expires?
      return true if @read_waiter.has_expires?
      return true if @take_waiter.has_expires?
      return true if @notify_waiter.has_expires?
    end

  end

end

