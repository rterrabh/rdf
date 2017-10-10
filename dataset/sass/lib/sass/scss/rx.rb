module Sass
  module SCSS
    module RX
      def self.escape_ident(str)
        return "" if str.empty?
        return "\\#{str}" if str == '-' || str == '_'
        out = ""
        value = str.dup
        out << value.slice!(0...1) if value =~ /^[-_]/
        if value[0...1] =~ NMSTART
          out << value.slice!(0...1)
        else
          out << escape_char(value.slice!(0...1))
        end
        out << value.gsub(/[^a-zA-Z0-9_-]/) {|c| escape_char c}
        out
      end

      def self.escape_char(c)
        return "\\%06x" % Sass::Util.ord(c) unless c =~ /[ -\/:-~]/
        "\\#{c}"
      end

      def self.quote(str, flags = 0)
        Regexp.new(Regexp.quote(str), flags)
      end

      H        = /[0-9a-fA-F]/
      NL       = /\n|\r\n|\r|\f/
      UNICODE  = /\\#{H}{1,6}[ \t\r\n\f]?/
      s = if Sass::Util.ruby1_8?
            '\200-\377'
          elsif Sass::Util.macruby?
            '\u0080-\uD7FF\uE000-\uFFFD\U00010000-\U0010FFFF'
          else
            '\u{80}-\u{D7FF}\u{E000}-\u{FFFD}\u{10000}-\u{10FFFF}'
          end
      NONASCII = /[#{s}]/
      ESCAPE   = /#{UNICODE}|\\[ -~#{s}]/
      NMSTART  = /[_a-zA-Z]|#{NONASCII}|#{ESCAPE}/
      NMCHAR   = /[a-zA-Z0-9_-]|#{NONASCII}|#{ESCAPE}/
      STRING1  = /\"((?:[^\n\r\f\\"]|\\#{NL}|#{ESCAPE})*)\"/
      STRING2  = /\'((?:[^\n\r\f\\']|\\#{NL}|#{ESCAPE})*)\'/

      IDENT    = /-*#{NMSTART}#{NMCHAR}*/
      NAME     = /#{NMCHAR}+/
      NUM      = //
      STRING   = /#{STRING1}|#{STRING2}/
      URLCHAR  = /[#%&*-~]|#{NONASCII}|#{ESCAPE}/
      URL      = /(#{URLCHAR}*)/
      W        = /[ \t\r\n\f]*/
      VARIABLE = /(\$)(#{Sass::SCSS::RX::IDENT})/

      RANGE    = /(?:#{H}|\?){1,6}/


      S = /[ \t\r\n\f]+/

      COMMENT = %r{/\*([^*]|\*+[^/*])*\**\*/}
      SINGLE_LINE_COMMENT = %r{//.*(\n[ \t]*//.*)*}

      CDO            = quote("<!--")
      CDC            = quote("-->")
      INCLUDES       = quote("~=")
      DASHMATCH      = quote("|=")
      PREFIXMATCH    = quote("^=")
      SUFFIXMATCH    = quote("$=")
      SUBSTRINGMATCH = quote("*=")

      HASH = /##{NAME}/

      IMPORTANT = /!#{W}important/i

      UNIT = /-?#{NMSTART}(?:[a-zA-Z0-9_]|#{NONASCII}|#{ESCAPE}|-(?!\d))*|%/

      UNITLESS_NUMBER = /(?:[0-9]+|[0-9]*\.[0-9]+)(?:[eE][+-]?\d+)?/
      NUMBER = /#{UNITLESS_NUMBER}(?:#{UNIT})?/
      PERCENTAGE = /#{UNITLESS_NUMBER}%/

      URI = /url\(#{W}(?:#{STRING}|#{URL})#{W}\)/i
      FUNCTION = /#{IDENT}\(/

      UNICODERANGE = /u\+(?:#{H}{1,6}-#{H}{1,6}|#{RANGE})/i

      PLUS = /#{W}\+/
      GREATER = /#{W}>/
      TILDE = /#{W}~/
      NOT = quote(":not(", Regexp::IGNORECASE)

      URL_PREFIX = /url-prefix\(#{W}(?:#{STRING}|#{URL})#{W}\)/i
      DOMAIN = /domain\(#{W}(?:#{STRING}|#{URL})#{W}\)/i

      HEXCOLOR = /\#[0-9a-fA-F]+/
      INTERP_START = /#\{/
      ANY = /:(-[-\w]+-)?any\(/i
      OPTIONAL = /!#{W}optional/i
      IDENT_START = /-|#{NMSTART}/

      IDENT_HYPHEN_INTERP = /-(#\{)/
      STRING1_NOINTERP = /\"((?:[^\n\r\f\\"#]|#(?!\{)|#{ESCAPE})*)\"/
      STRING2_NOINTERP = /\'((?:[^\n\r\f\\'#]|#(?!\{)|#{ESCAPE})*)\'/
      STRING_NOINTERP = /#{STRING1_NOINTERP}|#{STRING2_NOINTERP}/

      STATIC_COMPONENT = /#{IDENT}|#{STRING_NOINTERP}|#{HEXCOLOR}|[+-]?#{NUMBER}|\!important/i
      STATIC_VALUE = /#{STATIC_COMPONENT}(\s*[\s,\/]\s*#{STATIC_COMPONENT})*([;}])/i
      STATIC_SELECTOR = /(#{NMCHAR}|[ \t]|[,>+*]|[:#.]#{NMSTART}){1,50}([{])/i
    end
  end
end
