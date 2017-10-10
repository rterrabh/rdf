module Rake

  class EarlyTime
    include Comparable
    include Singleton


    def <=>(other)
      -1
    end

    def to_s # :nodoc:
      "<EARLY TIME>"
    end
  end

  EARLY = EarlyTime.instance
end
