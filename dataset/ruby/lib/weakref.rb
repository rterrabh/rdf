require "delegate"


class WeakRef < Delegator


  class RefError < StandardError
  end

  @@__map = ::ObjectSpace::WeakMap.new


  def initialize(orig)
    case orig
    when true, false, nil
      @delegate_sd_obj = orig
    else
      @@__map[self] = orig
    end
    super
  end

  def __getobj__ # :nodoc:
    @@__map[self] or defined?(@delegate_sd_obj) ? @delegate_sd_obj :
      Kernel::raise(RefError, "Invalid Reference - probably recycled", Kernel::caller(2))
  end

  def __setobj__(obj) # :nodoc:
  end


  def weakref_alive?
    @@__map.key?(self) or defined?(@delegate_sd_obj)
  end
end
