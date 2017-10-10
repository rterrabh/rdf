
module Observable

  def add_observer(observer, func=:update)
    @observer_peers = {} unless defined? @observer_peers
    unless observer.respond_to? func
      raise NoMethodError, "observer does not respond to `#{func}'"
    end
    @observer_peers[observer] = func
  end

  def delete_observer(observer)
    @observer_peers.delete observer if defined? @observer_peers
  end

  def delete_observers
    @observer_peers.clear if defined? @observer_peers
  end

  def count_observers
    if defined? @observer_peers
      @observer_peers.size
    else
      0
    end
  end

  def changed(state=true)
    @observer_state = state
  end

  def changed?
    if defined? @observer_state and @observer_state
      true
    else
      false
    end
  end

  def notify_observers(*arg)
    if defined? @observer_state and @observer_state
      if defined? @observer_peers
        @observer_peers.each do |k, v|
          #nodyna <send-2135> <SD MODERATE (change-prone variables)>
          k.send v, *arg
        end
      end
      @observer_state = false
    end
  end

end
