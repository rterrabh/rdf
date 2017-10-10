require 'rexml/security'
require 'rexml/entity'
require 'rexml/doctype'
require 'rexml/child'
require 'rexml/doctype'
require 'rexml/parseexception'

module REXML
  class Text < Child
    include Comparable
    SPECIALS = [ /&(?!#?[\w-]+;)/u, /</u, />/u, /"/u, /'/u, /\r/u ]
    SUBSTITUTES = ['&amp;', '&lt;', '&gt;', '&quot;', '&apos;', '&#13;']
    SLAICEPS = [ '<', '>', '"', "'", '&' ]
    SETUTITSBUS = [ /&lt;/u, /&gt;/u, /&quot;/u, /&apos;/u, /&amp;/u ]

    attr_accessor :raw

    NEEDS_A_SECOND_CHECK = /(<|&((#{Entity::NAME});|(#0*((?:\d+)|(?:x[a-fA-F0-9]+)));)?)/um
    NUMERICENTITY = /&#0*((?:\d+)|(?:x[a-fA-F0-9]+));/
    VALID_CHAR = [
      0x9, 0xA, 0xD,
      (0x20..0xD7FF),
      (0xE000..0xFFFD),
      (0x10000..0x10FFFF)
    ]

    if String.method_defined? :encode
      VALID_XML_CHARS = Regexp.new('^['+
        VALID_CHAR.map { |item|
          case item
          when Fixnum
            [item].pack('U').force_encoding('utf-8')
          when Range
            [item.first, '-'.ord, item.last].pack('UUU').force_encoding('utf-8')
          end
        }.join +
      ']*$')
    else
      VALID_XML_CHARS = /^(
           [\x09\x0A\x0D\x20-\x7E]            # ASCII
         | [\xC2-\xDF][\x80-\xBF]             # non-overlong 2-byte
         |  \xE0[\xA0-\xBF][\x80-\xBF]        # excluding overlongs
         | [\xE1-\xEC\xEE][\x80-\xBF]{2}      # straight 3-byte
         |  \xEF[\x80-\xBE]{2}                #
         |  \xEF\xBF[\x80-\xBD]               # excluding U+fffe and U+ffff
         |  \xED[\x80-\x9F][\x80-\xBF]        # excluding surrogates
         |  \xF0[\x90-\xBF][\x80-\xBF]{2}     # planes 1-3
         | [\xF1-\xF3][\x80-\xBF]{3}          # planes 4-15
         |  \xF4[\x80-\x8F][\x80-\xBF]{2}     # plane 16
       )*$/nx;
    end

    def initialize(arg, respect_whitespace=false, parent=nil, raw=nil,
      entity_filter=nil, illegal=NEEDS_A_SECOND_CHECK )

      @raw = false
      @parent = nil

      if parent
        super( parent )
        @raw = parent.raw
      end

      @raw = raw unless raw.nil?
      @entity_filter = entity_filter
      clear_cache

      if arg.kind_of? String
        @string = arg.dup
        @string.squeeze!(" \n\t") unless respect_whitespace
      elsif arg.kind_of? Text
        @string = arg.to_s
        @raw = arg.raw
      elsif
        raise "Illegal argument of type #{arg.type} for Text constructor (#{arg})"
      end

      @string.gsub!( /\r\n?/, "\n" )

      Text.check(@string, illegal, doctype) if @raw
    end

    def parent= parent
      super(parent)
      Text.check(@string, NEEDS_A_SECOND_CHECK, doctype) if @raw and @parent
    end

    def Text.check string, pattern, doctype

      if string !~ VALID_XML_CHARS
        if String.method_defined? :encode
          string.chars.each do |c|
            case c.ord
            when *VALID_CHAR
            else
              raise "Illegal character #{c.inspect} in raw string \"#{string}\""
            end
          end
        else
          string.scan(/[\x00-\x7F]|[\x80-\xBF][\xC0-\xF0]*|[\xC0-\xF0]/n) do |c|
            case c.unpack('U')
            when *VALID_CHAR
            else
              raise "Illegal character #{c.inspect} in raw string \"#{string}\""
            end
          end
        end
      end

      string.scan(pattern) do
        if $1[-1] != ?;
          raise "Illegal character '#{$1}' in raw string \"#{string}\""
        elsif $1[0] == ?&
          if $5 and $5[0] == ?#
            case ($5[1] == ?x ? $5[2..-1].to_i(16) : $5[1..-1].to_i)
            when *VALID_CHAR
            else
              raise "Illegal character '#{$1}' in raw string \"#{string}\""
            end
          end
        end
      end
    end

    def node_type
      :text
    end

    def empty?
      @string.size==0
    end


    def clone
      return Text.new(self)
    end


    def <<( to_append )
      @string << to_append.gsub( /\r\n?/, "\n" )
      clear_cache
      self
    end


    def <=>( other )
      to_s() <=> other.to_s
    end

    def doctype
      if @parent
        doc = @parent.document
        doc.doctype if doc
      end
    end

    REFERENCE = /#{Entity::REFERENCE}/
    def to_s
      return @string if @raw
      return @normalized if @normalized

      @normalized = Text::normalize( @string, doctype, @entity_filter )
    end

    def inspect
      @string.inspect
    end

    def value
      return @unnormalized if @unnormalized
      @unnormalized = Text::unnormalize( @string, doctype )
    end

    def value=( val )
      @string = val.gsub( /\r\n?/, "\n" )
      clear_cache
      @raw = false
    end

     def wrap(string, width, addnewline=false)
       return string if string.length <= width
       place = string.rindex(' ', width) # Position in string with last ' ' before cutoff
       if addnewline then
         return "\n" + string[0,place] + "\n" + wrap(string[place+1..-1], width)
       else
         return string[0,place] + "\n" + wrap(string[place+1..-1], width)
       end
     end

    def indent_text(string, level=1, style="\t", indentfirstline=true)
      return string if level < 0
      new_string = ''
      string.each_line { |line|
        indent_string = style * level
        new_line = (indent_string + line).sub(/[\s]+$/,'')
        new_string << new_line
      }
      new_string.strip! unless indentfirstline
      return new_string
    end

    def write( writer, indent=-1, transitive=false, ie_hack=false )
      Kernel.warn("#{self.class.name}.write is deprecated.  See REXML::Formatters")
      formatter = if indent > -1
          REXML::Formatters::Pretty.new( indent )
        else
          REXML::Formatters::Default.new
        end
      formatter.write( self, writer )
    end

    def xpath
      path = @parent.xpath
      path += "/text()"
      return path
    end

    def write_with_substitution out, input
      copy = input.clone
      copy.gsub!( SPECIALS[0], SUBSTITUTES[0] )
      copy.gsub!( SPECIALS[1], SUBSTITUTES[1] )
      copy.gsub!( SPECIALS[2], SUBSTITUTES[2] )
      copy.gsub!( SPECIALS[3], SUBSTITUTES[3] )
      copy.gsub!( SPECIALS[4], SUBSTITUTES[4] )
      copy.gsub!( SPECIALS[5], SUBSTITUTES[5] )
      out << copy
    end

    private
    def clear_cache
      @normalized = nil
      @unnormalized = nil
    end

    def Text::read_with_substitution( input, illegal=nil )
      copy = input.clone

      if copy =~ illegal
        raise ParseException.new( "malformed text: Illegal character #$& in \"#{copy}\"" )
      end if illegal

      copy.gsub!( /\r\n?/, "\n" )
      if copy.include? ?&
        copy.gsub!( SETUTITSBUS[0], SLAICEPS[0] )
        copy.gsub!( SETUTITSBUS[1], SLAICEPS[1] )
        copy.gsub!( SETUTITSBUS[2], SLAICEPS[2] )
        copy.gsub!( SETUTITSBUS[3], SLAICEPS[3] )
        copy.gsub!( SETUTITSBUS[4], SLAICEPS[4] )
        copy.gsub!( /&#0*((?:\d+)|(?:x[a-f0-9]+));/ ) {
          m=$1
          m = "0#{m}" if m[0] == ?x
          [Integer(m)].pack('U*')
        }
      end
      copy
    end

    EREFERENCE = /&(?!#{Entity::NAME};)/
    def Text::normalize( input, doctype=nil, entity_filter=nil )
      copy = input.to_s
      copy = copy.gsub( "&", "&amp;" )
      if doctype
        doctype.entities.each_value do |entity|
          copy = copy.gsub( entity.value,
            "&#{entity.name};" ) if entity.value and
              not( entity_filter and entity_filter.include?(entity.name) )
        end
      else
        DocType::DEFAULT_ENTITIES.each_value do |entity|
          copy = copy.gsub(entity.value, "&#{entity.name};" )
        end
      end
      copy
    end

    def Text::unnormalize( string, doctype=nil, filter=nil, illegal=nil )
      sum = 0
      string.gsub( /\r\n?/, "\n" ).gsub( REFERENCE ) {
        s = Text.expand($&, doctype, filter)
        if sum + s.bytesize > Security.entity_expansion_text_limit
          raise "entity expansion has grown too large"
        else
          sum += s.bytesize
        end
        s
      }
    end

    def Text.expand(ref, doctype, filter)
      if ref[1] == ?#
        if ref[2] == ?x
          [ref[3...-1].to_i(16)].pack('U*')
        else
          [ref[2...-1].to_i].pack('U*')
        end
      elsif ref == '&amp;'
        '&'
      elsif filter and filter.include?( ref[1...-1] )
        ref
      elsif doctype
        doctype.entity( ref[1...-1] ) or ref
      else
        entity_value = DocType::DEFAULT_ENTITIES[ ref[1...-1] ]
        entity_value ? entity_value.value : ref
      end
    end
  end
end
