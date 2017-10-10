

require 'thread'

module Mutex_m
  def Mutex_m.define_aliases(cl) # :nodoc:
    #nodyna <module_eval-2154> <not yet classified>
    cl.module_eval %q{
      alias locked? mu_locked?
      alias lock mu_lock
      alias unlock mu_unlock
      alias try_lock mu_try_lock
      alias synchronize mu_synchronize
    }
  end

  def Mutex_m.append_features(cl) # :nodoc:
    super
    define_aliases(cl) unless cl.instance_of?(Module)
  end

  def Mutex_m.extend_object(obj) # :nodoc:
    super
    obj.mu_extended
  end

  def mu_extended # :nodoc:
    unless (defined? locked? and
            defined? lock and
            defined? unlock and
            defined? try_lock and
            defined? synchronize)
      Mutex_m.define_aliases(singleton_class)
    end
    mu_initialize
  end

  def mu_synchronize(&block)
    @_mutex.synchronize(&block)
  end

  def mu_locked?
    @_mutex.locked?
  end

  def mu_try_lock
    @_mutex.try_lock
  end

  def mu_lock
    @_mutex.lock
  end

  def mu_unlock
    @_mutex.unlock
  end

  def sleep(timeout = nil)
    @_mutex.sleep(timeout)
  end

  private

  def mu_initialize # :nodoc:
    @_mutex = Mutex.new
  end

  def initialize(*args) # :nodoc:
    mu_initialize
    super
  end
end
