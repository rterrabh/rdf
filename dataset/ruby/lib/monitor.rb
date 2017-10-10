
require 'thread'

module MonitorMixin
  class ConditionVariable
    class Timeout < Exception; end

    def wait(timeout = nil)
      @monitor.__send__(:mon_check_owner)
      count = @monitor.__send__(:mon_exit_for_cond)
      begin
        #nodyna <instance_variable_get-2353> <not yet classified>
        @cond.wait(@monitor.instance_variable_get(:@mon_mutex), timeout)
        return true
      ensure
        @monitor.__send__(:mon_enter_for_cond, count)
      end
    end

    def wait_while
      while yield
        wait
      end
    end

    def wait_until
      until yield
        wait
      end
    end

    def signal
      @monitor.__send__(:mon_check_owner)
      @cond.signal
    end

    def broadcast
      @monitor.__send__(:mon_check_owner)
      @cond.broadcast
    end

    private

    def initialize(monitor)
      @monitor = monitor
      @cond = ::ConditionVariable.new
    end
  end

  def self.extend_object(obj)
    super(obj)
    obj.__send__(:mon_initialize)
  end

  def mon_try_enter
    if @mon_owner != Thread.current
      unless @mon_mutex.try_lock
        return false
      end
      @mon_owner = Thread.current
    end
    @mon_count += 1
    return true
  end
  alias try_mon_enter mon_try_enter

  def mon_enter
    if @mon_owner != Thread.current
      @mon_mutex.lock
      @mon_owner = Thread.current
    end
    @mon_count += 1
  end

  def mon_exit
    mon_check_owner
    @mon_count -=1
    if @mon_count == 0
      @mon_owner = nil
      @mon_mutex.unlock
    end
  end

  def mon_synchronize
    mon_enter
    begin
      yield
    ensure
      mon_exit
    end
  end
  alias synchronize mon_synchronize

  def new_cond
    return ConditionVariable.new(self)
  end

  private

  def initialize(*args)
    super
    mon_initialize
  end

  def mon_initialize
    @mon_owner = nil
    @mon_count = 0
    @mon_mutex = Mutex.new
  end

  def mon_check_owner
    if @mon_owner != Thread.current
      raise ThreadError, "current thread not owner"
    end
  end

  def mon_enter_for_cond(count)
    @mon_owner = Thread.current
    @mon_count = count
  end

  def mon_exit_for_cond
    count = @mon_count
    @mon_owner = nil
    @mon_count = 0
    return count
  end
end

class Monitor
  include MonitorMixin
  alias try_enter try_mon_enter
  alias enter mon_enter
  alias exit mon_exit
end



