
require 'uri'
str = "\xE6\x97\xA5\xE6\x9C\xAC\xE8\xAA\x9E" # Ni-ho-nn-go in UTF-8, means Japanese.
parser = URI::Parser.new

unless str == parser.unescape(parser.escape(str))
  #nodyna <class_eval-1100> <CE MODERATE (define methods)>
  URI::Parser.class_eval do
    remove_method :unescape
    def unescape(str, escaped = /%[a-fA-F\d]{2}/)
      enc = str.encoding
      enc = Encoding::UTF_8 if enc == Encoding::US_ASCII
      str.gsub(escaped) { [$&[1, 2].hex].pack('C') }.force_encoding(enc)
    end
  end
end

module URI
  class << self
    def parser
      @parser ||= URI::Parser.new
    end
  end
end
