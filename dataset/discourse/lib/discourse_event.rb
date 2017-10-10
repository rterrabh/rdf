module DiscourseEvent

  def self.events
    @events ||= Hash.new { |hash, key| hash[key] = Set.new }
  end

  def self.trigger(event_name, *params)
    events[event_name].each do |event|
      event.call(*params)
    end
  end

  def self.on(event_name, &block)
    events[event_name] << block
  end

  def self.off(event_name, &block)
    events[event_name].delete(block)
  end

  def self.clear
    @events = nil
  end

end
