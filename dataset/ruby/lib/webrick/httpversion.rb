
module WEBrick


  class HTTPVersion
    include Comparable


    attr_accessor :major


    attr_accessor :minor


    def self.convert(version)
      version.is_a?(self) ? version : new(version)
    end


    def initialize(version)
      case version
      when HTTPVersion
        @major, @minor = version.major, version.minor
      when String
        if /^(\d+)\.(\d+)$/ =~ version
          @major, @minor = $1.to_i, $2.to_i
        end
      end
      if @major.nil? || @minor.nil?
        raise ArgumentError,
          format("cannot convert %s into %s", version.class, self.class)
      end
    end


    def <=>(other)
      unless other.is_a?(self.class)
        other = self.class.new(other)
      end
      if (ret = @major <=> other.major) == 0
        return @minor <=> other.minor
      end
      return ret
    end


    def to_s
      format("%d.%d", @major, @minor)
    end
  end
end
