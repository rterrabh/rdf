
module Timeout
  class Error < RuntimeError
    attr_reader :thread

    def self.catch(*args)
      exc = new(*args)
      #nodyna <instance_variable_set-2049> <not yet classified>
      exc.instance_variable_set(:@thread, Thread.current)
      ::Kernel.catch(exc) {yield exc}
    end

    def exception(*)
      if self.thread == Thread.current
        bt = caller
        begin
          throw(self, bt)
        rescue UncaughtThrowError
        end
      end
      self
    end
  end
  ExitException = Error

  THIS_FILE = /\A#{Regexp.quote(__FILE__)}:/o
  CALLER_OFFSET = ((c = caller[0]) && THIS_FILE =~ c) ? 1 : 0

  def timeout(sec, klass = nil)   #:yield: +sec+
    return yield(sec) if sec == nil or sec.zero?
    message = "execution expired"
    e = Error
    bl = proc do |exception|
      begin
        x = Thread.current
        y = Thread.start {
          begin
            sleep sec
          rescue => e
            x.raise e
          else
            x.raise exception, message
          end
        }
        return yield(sec)
      ensure
        if y
          y.kill
          y.join # make sure y is dead.
        end
      end
    end
    if klass
      begin
        bl.call(klass)
      rescue klass => e
        bt = e.backtrace
      end
    else
      bt = Error.catch(message, &bl)
    end
    rej = /\A#{Regexp.quote(__FILE__)}:#{__LINE__-4}\z/o
    bt.reject! {|m| rej =~ m}
    level = -caller(CALLER_OFFSET).size
    while THIS_FILE =~ bt[level]
      bt.delete_at(level)
    end
    raise(e, message, bt)
  end

  module_function :timeout
end

def timeout(n, e = nil, &block)
  Timeout::timeout(n, e, &block)
end

TimeoutError = Timeout::Error
