module Jekyll
  class Plugin
    PRIORITIES = { :lowest => -100,
                   :low => -10,
                   :normal => 0,
                   :high => 10,
                   :highest => 100 }

    def self.descendants
      descendants = []
      ObjectSpace.each_object(singleton_class) do |k|
        descendants.unshift k unless k == self
      end
      descendants
    end

    def self.priority(priority = nil)
      @priority ||= nil
      if priority && PRIORITIES.key?(priority)
        @priority = priority
      end
      @priority || :normal
    end

    def self.safe(safe = nil)
      if safe
        @safe = safe
      end
      @safe || false
    end

    def self.<=>(other)
      PRIORITIES[other.priority] <=> PRIORITIES[self.priority]
    end

    def <=>(other)
      self.class <=> other.class
    end

    def initialize(config = {})
    end
  end
end
