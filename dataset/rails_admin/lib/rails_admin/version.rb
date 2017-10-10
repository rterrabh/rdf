module RailsAdmin
  class Version
    MAJOR = 0
    MINOR = 7
    PATCH = 0
    PRE = nil

    class << self
      def to_s
        [MAJOR, MINOR, PATCH, PRE].compact.join('.')
      end
    end
  end
end
