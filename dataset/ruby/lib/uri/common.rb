
require "uri/rfc2396_parser"
require "uri/rfc3986_parser"

module URI
  REGEXP = RFC2396_REGEXP
  Parser = RFC2396_Parser
  RFC3986_PARSER = RFC3986_Parser.new

  DEFAULT_PARSER = Parser.new
  DEFAULT_PARSER.pattern.each_pair do |sym, str|
    unless REGEXP::PATTERN.const_defined?(sym)
      #nodyna <const_set-2234> <CS COMPLEX (change-prone variable)>
      REGEXP::PATTERN.const_set(sym, str)
    end
  end
  DEFAULT_PARSER.regexp.each_pair do |sym, str|
    #nodyna <const_set-2235> <CS COMPLEX (change-prone variable)>
    const_set(sym, str)
  end

  module Util # :nodoc:
    def make_components_hash(klass, array_hash)
      tmp = {}
      if array_hash.kind_of?(Array) &&
          array_hash.size == klass.component.size - 1
        klass.component[1..-1].each_index do |i|
          begin
            tmp[klass.component[i + 1]] = array_hash[i].clone
          rescue TypeError
            tmp[klass.component[i + 1]] = array_hash[i]
          end
        end

      elsif array_hash.kind_of?(Hash)
        array_hash.each do |key, value|
          begin
            tmp[key] = value.clone
          rescue TypeError
            tmp[key] = value
          end
        end
      else
        raise ArgumentError,
          "expected Array of or Hash of components of #{klass} (#{klass.component[1..-1].join(', ')})"
      end
      tmp[:scheme] = klass.to_s.sub(/\A.*::/, '').downcase

      return tmp
    end
    module_function :make_components_hash
  end

  module Escape
    def escape(*arg)
      warn "#{caller(1)[0]}: warning: URI.escape is obsolete" if $VERBOSE
      DEFAULT_PARSER.escape(*arg)
    end
    alias encode escape
    def unescape(*arg)
      warn "#{caller(1)[0]}: warning: URI.unescape is obsolete" if $VERBOSE
      DEFAULT_PARSER.unescape(*arg)
    end
    alias decode unescape
  end # module Escape

  extend Escape
  include REGEXP

  @@schemes = {}
  def self.scheme_list
    @@schemes
  end

  class Error < StandardError; end
  class InvalidURIError < Error; end
  class InvalidComponentError < Error; end
  class BadURIError < Error; end

  def self.split(uri)
    RFC3986_PARSER.split(uri)
  end

  def self.parse(uri)
    RFC3986_PARSER.parse(uri)
  end

  def self.join(*str)
    RFC3986_PARSER.join(*str)
  end

  def self.extract(str, schemes = nil, &block)
    warn "#{caller(1)[0]}: warning: URI.extract is obsolete" if $VERBOSE
    DEFAULT_PARSER.extract(str, schemes, &block)
  end

  def self.regexp(schemes = nil)
    warn "#{caller(1)[0]}: warning: URI.regexp is obsolete" if $VERBOSE
    DEFAULT_PARSER.make_regexp(schemes)
  end

  TBLENCWWWCOMP_ = {} # :nodoc:
  256.times do |i|
    TBLENCWWWCOMP_[i.chr] = '%%%02X' % i
  end
  TBLENCWWWCOMP_[' '] = '+'
  TBLENCWWWCOMP_.freeze
  TBLDECWWWCOMP_ = {} # :nodoc:
  256.times do |i|
    h, l = i>>4, i&15
    TBLDECWWWCOMP_['%%%X%X' % [h, l]] = i.chr
    TBLDECWWWCOMP_['%%%x%X' % [h, l]] = i.chr
    TBLDECWWWCOMP_['%%%X%x' % [h, l]] = i.chr
    TBLDECWWWCOMP_['%%%x%x' % [h, l]] = i.chr
  end
  TBLDECWWWCOMP_['+'] = ' '
  TBLDECWWWCOMP_.freeze

  HTML5ASCIIINCOMPAT = [Encoding::UTF_7, Encoding::UTF_16BE, Encoding::UTF_16LE,
    Encoding::UTF_32BE, Encoding::UTF_32LE] # :nodoc:

  def self.encode_www_form_component(str, enc=nil)
    str = str.to_s.dup
    if str.encoding != Encoding::ASCII_8BIT
      if enc && enc != Encoding::ASCII_8BIT
        str.encode!(Encoding::UTF_8, invalid: :replace, undef: :replace)
        str.encode!(enc, fallback: ->(x){"&#{x.ord};"})
      end
      str.force_encoding(Encoding::ASCII_8BIT)
    end
    str.gsub!(/[^*\-.0-9A-Z_a-z]/, TBLENCWWWCOMP_)
    str.force_encoding(Encoding::US_ASCII)
  end

  def self.decode_www_form_component(str, enc=Encoding::UTF_8)
    raise ArgumentError, "invalid %-encoding (#{str})" if /%(?!\h\h)/ =~ str
    str.b.gsub(/\+|%\h\h/, TBLDECWWWCOMP_).force_encoding(enc)
  end

  def self.encode_www_form(enum, enc=nil)
    enum.map do |k,v|
      if v.nil?
        encode_www_form_component(k, enc)
      elsif v.respond_to?(:to_ary)
        v.to_ary.map do |w|
          str = encode_www_form_component(k, enc)
          unless w.nil?
            str << '='
            str << encode_www_form_component(w, enc)
          end
        end.join('&')
      else
        str = encode_www_form_component(k, enc)
        str << '='
        str << encode_www_form_component(v, enc)
      end
    end.join('&')
  end

  def self.decode_www_form(str, enc=Encoding::UTF_8, separator: '&', use__charset_: false, isindex: false)
    raise ArgumentError, "the input of #{self.name}.#{__method__} must be ASCII only string" unless str.ascii_only?
    ary = []
    return ary if str.empty?
    enc = Encoding.find(enc)
    str.b.each_line(separator) do |string|
      string.chomp!(separator)
      key, sep, val = string.partition('=')
      if isindex
        if sep.empty?
          val = key
          key = ''
        end
        isindex = false
      end

      if use__charset_ and key == '_charset_' and e = get_encoding(val)
        enc = e
        use__charset_ = false
      end

      key.gsub!(/\+|%\h\h/, TBLDECWWWCOMP_)
      if val
        val.gsub!(/\+|%\h\h/, TBLDECWWWCOMP_)
      else
        val = ''
      end

      ary << [key, val]
    end
    ary.each do |k, v|
      k.force_encoding(enc)
      k.scrub!
      v.force_encoding(enc)
      v.scrub!
    end
    ary
  end

  private
  WEB_ENCODINGS_ = {
    "unicode-1-1-utf-8"=>"utf-8",
    "utf-8"=>"utf-8",
    "utf8"=>"utf-8",
    "866"=>"ibm866",
    "cp866"=>"ibm866",
    "csibm866"=>"ibm866",
    "ibm866"=>"ibm866",
    "csisolatin2"=>"iso-8859-2",
    "iso-8859-2"=>"iso-8859-2",
    "iso-ir-101"=>"iso-8859-2",
    "iso8859-2"=>"iso-8859-2",
    "iso88592"=>"iso-8859-2",
    "iso_8859-2"=>"iso-8859-2",
    "iso_8859-2:1987"=>"iso-8859-2",
    "l2"=>"iso-8859-2",
    "latin2"=>"iso-8859-2",
    "csisolatin3"=>"iso-8859-3",
    "iso-8859-3"=>"iso-8859-3",
    "iso-ir-109"=>"iso-8859-3",
    "iso8859-3"=>"iso-8859-3",
    "iso88593"=>"iso-8859-3",
    "iso_8859-3"=>"iso-8859-3",
    "iso_8859-3:1988"=>"iso-8859-3",
    "l3"=>"iso-8859-3",
    "latin3"=>"iso-8859-3",
    "csisolatin4"=>"iso-8859-4",
    "iso-8859-4"=>"iso-8859-4",
    "iso-ir-110"=>"iso-8859-4",
    "iso8859-4"=>"iso-8859-4",
    "iso88594"=>"iso-8859-4",
    "iso_8859-4"=>"iso-8859-4",
    "iso_8859-4:1988"=>"iso-8859-4",
    "l4"=>"iso-8859-4",
    "latin4"=>"iso-8859-4",
    "csisolatincyrillic"=>"iso-8859-5",
    "cyrillic"=>"iso-8859-5",
    "iso-8859-5"=>"iso-8859-5",
    "iso-ir-144"=>"iso-8859-5",
    "iso8859-5"=>"iso-8859-5",
    "iso88595"=>"iso-8859-5",
    "iso_8859-5"=>"iso-8859-5",
    "iso_8859-5:1988"=>"iso-8859-5",
    "arabic"=>"iso-8859-6",
    "asmo-708"=>"iso-8859-6",
    "csiso88596e"=>"iso-8859-6",
    "csiso88596i"=>"iso-8859-6",
    "csisolatinarabic"=>"iso-8859-6",
    "ecma-114"=>"iso-8859-6",
    "iso-8859-6"=>"iso-8859-6",
    "iso-8859-6-e"=>"iso-8859-6",
    "iso-8859-6-i"=>"iso-8859-6",
    "iso-ir-127"=>"iso-8859-6",
    "iso8859-6"=>"iso-8859-6",
    "iso88596"=>"iso-8859-6",
    "iso_8859-6"=>"iso-8859-6",
    "iso_8859-6:1987"=>"iso-8859-6",
    "csisolatingreek"=>"iso-8859-7",
    "ecma-118"=>"iso-8859-7",
    "elot_928"=>"iso-8859-7",
    "greek"=>"iso-8859-7",
    "greek8"=>"iso-8859-7",
    "iso-8859-7"=>"iso-8859-7",
    "iso-ir-126"=>"iso-8859-7",
    "iso8859-7"=>"iso-8859-7",
    "iso88597"=>"iso-8859-7",
    "iso_8859-7"=>"iso-8859-7",
    "iso_8859-7:1987"=>"iso-8859-7",
    "sun_eu_greek"=>"iso-8859-7",
    "csiso88598e"=>"iso-8859-8",
    "csisolatinhebrew"=>"iso-8859-8",
    "hebrew"=>"iso-8859-8",
    "iso-8859-8"=>"iso-8859-8",
    "iso-8859-8-e"=>"iso-8859-8",
    "iso-ir-138"=>"iso-8859-8",
    "iso8859-8"=>"iso-8859-8",
    "iso88598"=>"iso-8859-8",
    "iso_8859-8"=>"iso-8859-8",
    "iso_8859-8:1988"=>"iso-8859-8",
    "visual"=>"iso-8859-8",
    "csisolatin6"=>"iso-8859-10",
    "iso-8859-10"=>"iso-8859-10",
    "iso-ir-157"=>"iso-8859-10",
    "iso8859-10"=>"iso-8859-10",
    "iso885910"=>"iso-8859-10",
    "l6"=>"iso-8859-10",
    "latin6"=>"iso-8859-10",
    "iso-8859-13"=>"iso-8859-13",
    "iso8859-13"=>"iso-8859-13",
    "iso885913"=>"iso-8859-13",
    "iso-8859-14"=>"iso-8859-14",
    "iso8859-14"=>"iso-8859-14",
    "iso885914"=>"iso-8859-14",
    "csisolatin9"=>"iso-8859-15",
    "iso-8859-15"=>"iso-8859-15",
    "iso8859-15"=>"iso-8859-15",
    "iso885915"=>"iso-8859-15",
    "iso_8859-15"=>"iso-8859-15",
    "l9"=>"iso-8859-15",
    "iso-8859-16"=>"iso-8859-16",
    "cskoi8r"=>"koi8-r",
    "koi"=>"koi8-r",
    "koi8"=>"koi8-r",
    "koi8-r"=>"koi8-r",
    "koi8_r"=>"koi8-r",
    "koi8-u"=>"koi8-u",
    "dos-874"=>"windows-874",
    "iso-8859-11"=>"windows-874",
    "iso8859-11"=>"windows-874",
    "iso885911"=>"windows-874",
    "tis-620"=>"windows-874",
    "windows-874"=>"windows-874",
    "cp1250"=>"windows-1250",
    "windows-1250"=>"windows-1250",
    "x-cp1250"=>"windows-1250",
    "cp1251"=>"windows-1251",
    "windows-1251"=>"windows-1251",
    "x-cp1251"=>"windows-1251",
    "ansi_x3.4-1968"=>"windows-1252",
    "ascii"=>"windows-1252",
    "cp1252"=>"windows-1252",
    "cp819"=>"windows-1252",
    "csisolatin1"=>"windows-1252",
    "ibm819"=>"windows-1252",
    "iso-8859-1"=>"windows-1252",
    "iso-ir-100"=>"windows-1252",
    "iso8859-1"=>"windows-1252",
    "iso88591"=>"windows-1252",
    "iso_8859-1"=>"windows-1252",
    "iso_8859-1:1987"=>"windows-1252",
    "l1"=>"windows-1252",
    "latin1"=>"windows-1252",
    "us-ascii"=>"windows-1252",
    "windows-1252"=>"windows-1252",
    "x-cp1252"=>"windows-1252",
    "cp1253"=>"windows-1253",
    "windows-1253"=>"windows-1253",
    "x-cp1253"=>"windows-1253",
    "cp1254"=>"windows-1254",
    "csisolatin5"=>"windows-1254",
    "iso-8859-9"=>"windows-1254",
    "iso-ir-148"=>"windows-1254",
    "iso8859-9"=>"windows-1254",
    "iso88599"=>"windows-1254",
    "iso_8859-9"=>"windows-1254",
    "iso_8859-9:1989"=>"windows-1254",
    "l5"=>"windows-1254",
    "latin5"=>"windows-1254",
    "windows-1254"=>"windows-1254",
    "x-cp1254"=>"windows-1254",
    "cp1255"=>"windows-1255",
    "windows-1255"=>"windows-1255",
    "x-cp1255"=>"windows-1255",
    "cp1256"=>"windows-1256",
    "windows-1256"=>"windows-1256",
    "x-cp1256"=>"windows-1256",
    "cp1257"=>"windows-1257",
    "windows-1257"=>"windows-1257",
    "x-cp1257"=>"windows-1257",
    "cp1258"=>"windows-1258",
    "windows-1258"=>"windows-1258",
    "x-cp1258"=>"windows-1258",
    "x-mac-cyrillic"=>"macCyrillic",
    "x-mac-ukrainian"=>"macCyrillic",
    "chinese"=>"gbk",
    "csgb2312"=>"gbk",
    "csiso58gb231280"=>"gbk",
    "gb2312"=>"gbk",
    "gb_2312"=>"gbk",
    "gb_2312-80"=>"gbk",
    "gbk"=>"gbk",
    "iso-ir-58"=>"gbk",
    "x-gbk"=>"gbk",
    "gb18030"=>"gb18030",
    "big5"=>"big5",
    "big5-hkscs"=>"big5",
    "cn-big5"=>"big5",
    "csbig5"=>"big5",
    "x-x-big5"=>"big5",
    "cseucpkdfmtjapanese"=>"cp51932",
    "euc-jp"=>"cp51932",
    "x-euc-jp"=>"cp51932",
    "csiso2022jp"=>"cp50221",
    "iso-2022-jp"=>"cp50221",
    "csshiftjis"=>"Windows-31J",
    "ms_kanji"=>"Windows-31J",
    "shift-jis"=>"Windows-31J",
    "shift_jis"=>"Windows-31J",
    "sjis"=>"Windows-31J",
    "windows-31j"=>"Windows-31J",
    "x-sjis"=>"Windows-31J",
    "cseuckr"=>"euc-kr",
    "csksc56011987"=>"euc-kr",
    "euc-kr"=>"euc-kr",
    "iso-ir-149"=>"euc-kr",
    "korean"=>"euc-kr",
    "ks_c_5601-1987"=>"euc-kr",
    "ks_c_5601-1989"=>"euc-kr",
    "ksc5601"=>"euc-kr",
    "ksc_5601"=>"euc-kr",
    "windows-949"=>"euc-kr",
    "utf-16be"=>"utf-16be",
    "utf-16"=>"utf-16le",
    "utf-16le"=>"utf-16le"
  } # :nodoc:

  def self.get_encoding(label)
    Encoding.find(WEB_ENCODINGS_[label.to_str.strip.downcase]) rescue nil
  end
end # module URI

module Kernel

  def URI(uri)
    if uri.is_a?(URI::Generic)
      uri
    elsif uri = String.try_convert(uri)
      URI.parse(uri)
    else
      raise ArgumentError,
        "bad argument (expected URI object or URI string)"
    end
  end
  module_function :URI
end
