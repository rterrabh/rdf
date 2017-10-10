class CGI; module Util; end; extend Util; end
module CGI::Util
  @@accept_charset="UTF-8" unless defined?(@@accept_charset)
  def escape(string)
    encoding = string.encoding
    string.b.gsub(/([^ a-zA-Z0-9_.-]+)/) do |m|
      '%' + m.unpack('H2' * m.bytesize).join('%').upcase
    end.tr(' ', '+').force_encoding(encoding)
  end

  def unescape(string,encoding=@@accept_charset)
    str=string.tr('+', ' ').b.gsub(/((?:%[0-9a-fA-F]{2})+)/) do |m|
      [m.delete('%')].pack('H*')
    end.force_encoding(encoding)
    str.valid_encoding? ? str : str.force_encoding(string.encoding)
  end

  TABLE_FOR_ESCAPE_HTML__ = {
    "'" => '&#39;',
    '&' => '&amp;',
    '"' => '&quot;',
    '<' => '&lt;',
    '>' => '&gt;',
  }

  def escapeHTML(string)
    string.gsub(/['&\"<>]/, TABLE_FOR_ESCAPE_HTML__)
  end

  def unescapeHTML(string)
    return string unless string.include? '&'
    enc = string.encoding
    if enc != Encoding::UTF_8 && [Encoding::UTF_16BE, Encoding::UTF_16LE, Encoding::UTF_32BE, Encoding::UTF_32LE].include?(enc)
      return string.gsub(Regexp.new('&(apos|amp|quot|gt|lt|#[0-9]+|#x[0-9A-Fa-f]+);'.encode(enc))) do
        case $1.encode(Encoding::US_ASCII)
        when 'apos'                then "'".encode(enc)
        when 'amp'                 then '&'.encode(enc)
        when 'quot'                then '"'.encode(enc)
        when 'gt'                  then '>'.encode(enc)
        when 'lt'                  then '<'.encode(enc)
        when /\A#0*(\d+)\z/        then $1.to_i.chr(enc)
        when /\A#x([0-9a-f]+)\z/i  then $1.hex.chr(enc)
        end
      end
    end
    asciicompat = Encoding.compatible?(string, "a")
    string.gsub(/&(apos|amp|quot|gt|lt|\#[0-9]+|\#[xX][0-9A-Fa-f]+);/) do
      match = $1.dup
      case match
      when 'apos'                then "'"
      when 'amp'                 then '&'
      when 'quot'                then '"'
      when 'gt'                  then '>'
      when 'lt'                  then '<'
      when /\A#0*(\d+)\z/
        n = $1.to_i
        if enc == Encoding::UTF_8 or
          enc == Encoding::ISO_8859_1 && n < 256 or
          asciicompat && n < 128
          n.chr(enc)
        else
          "&##{$1};"
        end
      when /\A#x([0-9a-f]+)\z/i
        n = $1.hex
        if enc == Encoding::UTF_8 or
          enc == Encoding::ISO_8859_1 && n < 256 or
          asciicompat && n < 128
          n.chr(enc)
        else
          "&#x#{$1};"
        end
      else
        "&#{match};"
      end
    end
  end

  alias escape_html escapeHTML

  alias unescape_html unescapeHTML

  def escapeElement(string, *elements)
    elements = elements[0] if elements[0].kind_of?(Array)
    unless elements.empty?
      string.gsub(/<\/?(?:#{elements.join("|")})(?!\w)(?:.|\n)*?>/i) do
        CGI::escapeHTML($&)
      end
    else
      string
    end
  end

  def unescapeElement(string, *elements)
    elements = elements[0] if elements[0].kind_of?(Array)
    unless elements.empty?
      string.gsub(/&lt;\/?(?:#{elements.join("|")})(?!\w)(?:.|\n)*?&gt;/i) do
        unescapeHTML($&)
      end
    else
      string
    end
  end

  alias escape_element escapeElement

  alias unescape_element unescapeElement

  RFC822_DAYS = %w[ Sun Mon Tue Wed Thu Fri Sat ]

  RFC822_MONTHS = %w[ Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec ]

  def rfc1123_date(time)
    t = time.clone.gmtime
    return format("%s, %.2d %s %.4d %.2d:%.2d:%.2d GMT",
                  RFC822_DAYS[t.wday], t.day, RFC822_MONTHS[t.month-1], t.year,
                  t.hour, t.min, t.sec)
  end

  def pretty(string, shift = "  ")
    lines = string.gsub(/(?!\A)<.*?>/m, "\n\\0").gsub(/<.*?>(?!\n)/m, "\\0\n")
    end_pos = 0
    while end_pos = lines.index(/^<\/(\w+)/, end_pos)
      element = $1.dup
      start_pos = lines.rindex(/^\s*<#{element}/i, end_pos)
      lines[start_pos ... end_pos] = "__" + lines[start_pos ... end_pos].gsub(/\n(?!\z)/, "\n" + shift) + "__"
    end
    lines.gsub(/^((?:#{Regexp::quote(shift)})*)__(?=<\/?\w)/, '\1')
  end

  alias h escapeHTML
end
