require 'strscan'

if Sass::Util.ruby1_8?
  Sass::Util::MultibyteStringScanner = StringScanner
else
  if Sass::Util.rbx?
    require 'delegate'
    class Sass::Util::MultibyteStringScanner < DelegateClass(StringScanner)
      def initialize(str)
        super(StringScanner.new(str))
        @mb_pos = 0
        @mb_matched_size = nil
        @mb_last_pos = nil
      end

      def is_a?(klass)
        __getobj__.is_a?(klass) || super
      end
    end
  else
    class Sass::Util::MultibyteStringScanner < StringScanner
      def initialize(str)
        super
        @mb_pos = 0
        @mb_matched_size = nil
        @mb_last_pos = nil
      end
    end
  end

  class Sass::Util::MultibyteStringScanner
    def self.new(str)
      return StringScanner.new(str) if str.ascii_only?
      super
    end

    alias_method :byte_pos, :pos
    alias_method :byte_matched_size, :matched_size

    def check(pattern); _match super; end
    def check_until(pattern); _matched super; end
    def getch; _forward _match super; end
    def match?(pattern); _size check(pattern); end
    def matched_size; @mb_matched_size; end
    def peek(len); string[@mb_pos, len]; end
    alias_method :peep, :peek
    def pos; @mb_pos; end
    alias_method :pointer, :pos
    def rest_size; rest.size; end
    def scan(pattern); _forward _match super; end
    def scan_until(pattern); _forward _matched super; end
    def skip(pattern); _size scan(pattern); end
    def skip_until(pattern); _matched _size scan_until(pattern); end

    def get_byte
      raise "MultibyteStringScanner doesn't support #get_byte."
    end

    def getbyte
      raise "MultibyteStringScanner doesn't support #getbyte."
    end

    def pos=(n)
      @mb_last_pos = nil

      if @mb_pos - n < @mb_pos / 2
        byte_delta = @mb_pos > n ? -string[n...@mb_pos].bytesize : string[@mb_pos...n].bytesize
        super(byte_pos + byte_delta)
      else
        super(string[0...n].bytesize)
      end
      @mb_pos = n
    end

    def reset
      @mb_pos = 0
      @mb_matched_size = nil
      @mb_last_pos = nil
      super
    end

    def scan_full(pattern, advance_pointer_p, return_string_p)
      res = _match super(pattern, advance_pointer_p, true)
      _forward res if advance_pointer_p
      return res if return_string_p
    end

    def search_full(pattern, advance_pointer_p, return_string_p)
      res = super(pattern, advance_pointer_p, true)
      _forward res if advance_pointer_p
      _matched((res if return_string_p))
    end

    def string=(str)
      @mb_pos = 0
      @mb_matched_size = nil
      @mb_last_pos = nil
      super
    end

    def terminate
      @mb_pos = string.size
      @mb_matched_size = nil
      @mb_last_pos = nil
      super
    end
    alias_method :clear, :terminate

    def unscan
      super
      @mb_pos = @mb_last_pos
      @mb_last_pos = @mb_matched_size = nil
    end

    private

    def _size(str)
      str && str.size
    end

    def _match(str)
      @mb_matched_size = str && str.size
      str
    end

    def _matched(res)
      _match matched
      res
    end

    def _forward(str)
      @mb_last_pos = @mb_pos
      @mb_pos += str.size if str
      str
    end
  end
end
