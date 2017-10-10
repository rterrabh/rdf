module Rake
  class LateTime
    include Comparable
    include Singleton

    def <=>(other)
      1
    end

    def to_s
      '<LATE TIME>'
    end
  end

  LATE = LateTime.instance
end
