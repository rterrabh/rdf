
module Scanf


  class FormatSpecifier

    attr_reader :re_string, :matched_string, :conversion, :matched

    private

    def skip;  /^\s*%\*/.match(@spec_string); end

    def extract_float(s)
      return nil unless s &&! skip
      if /\A(?<sign>[-+]?)0[xX](?<frac>\.\h+|\h+(?:\.\h*)?)[pP](?<exp>[-+]\d+)/ =~ s
        f1, f2 = frac.split('.')
        f = f1.hex
        if f2
          len = f2.length
          if len > 0
            f += f2.hex / (16.0 ** len)
          end
        end
        (sign == ?- ? -1 : 1) * Math.ldexp(f, exp.to_i)
      elsif /\A([-+]?\d+)\.([eE][-+]\d+)/ =~ s
        ($1 << $2).to_f
      else
        s.to_f
      end
    end
    def extract_decimal(s); s.to_i if s &&! skip; end
    def extract_hex(s); s.hex if s &&! skip; end
    def extract_octal(s); s.oct if s &&! skip; end
    def extract_integer(s); Integer(s) if s &&! skip; end
    def extract_plain(s); s unless skip; end

    def nil_proc(s); nil; end

    public

    def to_s
      @spec_string
    end

    def count_space?
      /(?:\A|\S)%\*?\d*c|%\d*\[/.match(@spec_string)
    end

    def initialize(str)
      @spec_string = str
      h = '[A-Fa-f0-9]'

      @re_string, @handler =
        case @spec_string

        when /%\*?(\[\[:[a-z]+:\]\])/
          [ "(#{$1}+)", :extract_plain ]

        when /%\*?(\d+)(\[\[:[a-z]+:\]\])/
          [ "(#{$2}{1,#{$1}})", :extract_plain ]

        when /%\*?\[([^\]]*)\]/
          yes = $1
          if /^\^/.match(yes) then no = yes[1..-1] else no = '^' + yes end
          [ "([#{yes}]+)(?=[#{no}]|\\z)", :extract_plain ]

        when /%\*?(\d+)\[([^\]]*)\]/
          yes = $2
          w = $1
          [ "([#{yes}]{1,#{w}})", :extract_plain ]

        when /%\*?i/
          [ "([-+]?(?:(?:0[0-7]+)|(?:0[Xx]#{h}+)|(?:[1-9]\\d*)))", :extract_integer ]

        when /%\*?(\d+)i/
          n = $1.to_i
          s = "("
          if n > 1 then s += "[1-9]\\d{1,#{n-1}}|" end
          if n > 1 then s += "0[0-7]{1,#{n-1}}|" end
          if n > 2 then s += "[-+]0[0-7]{1,#{n-2}}|" end
          if n > 2 then s += "[-+][1-9]\\d{1,#{n-2}}|" end
          if n > 2 then s += "0[Xx]#{h}{1,#{n-2}}|" end
          if n > 3 then s += "[-+]0[Xx]#{h}{1,#{n-3}}|" end
          s += "\\d"
          s += ")"
          [ s, :extract_integer ]

        when /%\*?[du]/
          [ '([-+]?\d+)', :extract_decimal ]

        when /%\*?(\d+)[du]/
          n = $1.to_i
          s = "("
          if n > 1 then s += "[-+]\\d{1,#{n-1}}|" end
          s += "\\d{1,#{$1}})"
          [ s, :extract_decimal ]

        when /%\*?[Xx]/
          [ "([-+]?(?:0[Xx])?#{h}+)", :extract_hex ]

        when /%\*?(\d+)[Xx]/
          n = $1.to_i
          s = "("
          if n > 3 then s += "[-+]0[Xx]#{h}{1,#{n-3}}|" end
          if n > 2 then s += "0[Xx]#{h}{1,#{n-2}}|" end
          if n > 1 then s += "[-+]#{h}{1,#{n-1}}|" end
          s += "#{h}{1,#{n}}"
          s += ")"
          [ s, :extract_hex ]

        when /%\*?o/
          [ '([-+]?[0-7]+)', :extract_octal ]

        when /%\*?(\d+)o/
          [ "([-+][0-7]{1,#{$1.to_i-1}}|[0-7]{1,#{$1}})", :extract_octal ]

        when /%\*?[aefgAEFG]/
          [ '([-+]?(?:0[xX](?:\.\h+|\h+(?:\.\h*)?)[pP][-+]\d+|\d+(?![\d.])|\d*\.\d*(?:[eE][-+]?\d+)?))', :extract_float ]

        when /%\*?(\d+)[aefgAEFG]/
          [ '(?=[-+]?(?:0[xX](?:\.\h+|\h+(?:\.\h*)?)[pP][-+]\d+|\d+(?![\d.])|\d*\.\d*(?:[eE][-+]?\d+)?))' +
            "(\\S{1,#{$1}})", :extract_float ]

        when /%\*?(\d+)s/
          [ "(\\S{1,#{$1}})", :extract_plain ]

        when /%\*?s/
          [ '(\S+)', :extract_plain ]

        when /\s%\*?c/
          [ "\\s*(.)", :extract_plain ]

        when /%\*?c/
          [ "(.)", :extract_plain ]

        when /%\*?(\d+)c/
          [ "(.{1,#{$1}})", :extract_plain ]

        when /%%/
          [ '(\s*%)', :nil_proc ]

        else
          [ "(#{Regexp.escape(@spec_string)})", :nil_proc ]
        end

      @re_string = '\A' + @re_string
    end

    def to_re
      Regexp.new(@re_string,Regexp::MULTILINE)
    end

    def match(str)
      @matched = false
      s = str.dup
      s.sub!(/\A\s+/,'') unless count_space?
      res = to_re.match(s)
      if res
        #nodyna <send-2153> <SD COMPLEX (change-prone variables)>
        @conversion = send(@handler, res[1])
        @matched_string = @conversion.to_s
        @matched = true
      end
      res
    end

    def letter
      @spec_string[/%\*?\d*([a-z\[])/, 1]
    end

    def width
      w = @spec_string[/%\*?(\d+)/, 1]
      w && w.to_i
    end

    def mid_match?
      return false unless @matched
      cc_no_width    = letter == '[' &&! width
      c_or_cc_width  = (letter == 'c' || letter == '[') && width
      width_left     = c_or_cc_width && (matched_string.size < width)

      return width_left || cc_no_width
    end

  end

  class FormatString

    attr_reader :string_left, :last_spec_tried,
                :last_match_tried, :matched_count, :space

    SPECIFIERS = 'diuXxofFeEgGscaA'
    REGEX = /
          (?:\s*
            %
              (?:%|
                 \*?
                 \d*
                   (?:\[\[:\w+:\]\]|
                      \[[^\]]*\]|
                      [#{SPECIFIERS}])))|
              [^%\s]+/ix

    def initialize(str)
      @specs = []
      @i = 1
      s = str.to_s
      return unless /\S/.match(s)
      @space = true if /\s\z/.match(s)
      @specs.replace s.scan(REGEX).map {|spec| FormatSpecifier.new(spec) }
    end

    def to_s
      @specs.join('')
    end

    def prune(n=matched_count)
      n.times { @specs.shift }
    end

    def spec_count
      @specs.size
    end

    def last_spec
      @i == spec_count - 1
    end

    def match(str)
      accum = []
      @string_left = str
      @matched_count = 0

      @specs.each_with_index do |spec,i|
        @i=i
        @last_spec_tried = spec
        @last_match_tried = spec.match(@string_left)
        break unless @last_match_tried
        @matched_count += 1

        accum << spec.conversion

        @string_left = @last_match_tried.post_match
        break if @string_left.empty?
      end
      return accum.compact
    end
  end
end

class IO


  def scanf(str,&b) #:yield: current_match
    return block_scanf(str,&b) if b
    return [] unless str.size > 0

    start_position = pos rescue 0
    matched_so_far = 0
    source_buffer = ""
    result_buffer = []
    final_result = []

    fstr = Scanf::FormatString.new(str)

    loop do
      if eof || (tty? &&! fstr.match(source_buffer))
        final_result.concat(result_buffer)
        break
      end

      source_buffer << gets

      current_match = fstr.match(source_buffer)

      spec = fstr.last_spec_tried

      if spec.matched
        if spec.mid_match?
          result_buffer.replace(current_match)
          next
        end

      elsif (fstr.matched_count == fstr.spec_count - 1)
        if /\A\s*\z/.match(fstr.string_left)
          break if spec.count_space?
          result_buffer.replace(current_match)
          next
        end
      end

      final_result.concat(current_match)

      matched_so_far += source_buffer.size
      source_buffer.replace(fstr.string_left)
      matched_so_far -= source_buffer.size
      break if fstr.last_spec
      fstr.prune
    end

    begin
      seek(start_position + matched_so_far, IO::SEEK_SET)
    rescue Errno::ESPIPE
    end

    soak_up_spaces if fstr.last_spec && fstr.space

    return final_result
  end

  private

  def soak_up_spaces
    c = getc
    ungetc(c) if c
    until eof ||! c || /\S/.match(c.chr)
      c = getc
    end
    ungetc(c) if (c && /\S/.match(c.chr))
  end

  def block_scanf(str)
    final = []
    fstr = Scanf::FormatString.new(str)
    last_spec = fstr.last_spec
    begin
      current = scanf(str)
      break if current.empty?
      final.push(yield(current))
    end until eof || fstr.last_spec_tried == last_spec
    return final
  end
end

class String


  def scanf(fstr,&b) #:yield: current_match
    if b
      block_scanf(fstr,&b)
    else
      fs =
        if fstr.is_a? Scanf::FormatString
          fstr
        else
          Scanf::FormatString.new(fstr)
        end
      fs.match(self)
    end
  end

  def block_scanf(fstr) #:yield: current_match
    fs = Scanf::FormatString.new(fstr)
    str = self.dup
    final = []
    begin
      current = str.scanf(fs)
      final.push(yield(current)) unless current.empty?
      str = fs.string_left
    end until current.empty? || str.empty?
    return final
  end
end

module Kernel
  private
  def scanf(format, &b) #:doc:
    STDIN.scanf(format ,&b)
  end
end
