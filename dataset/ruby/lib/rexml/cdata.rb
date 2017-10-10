require "rexml/text"

module REXML
  class CData < Text
    START = '<![CDATA['
    STOP = ']]>'
    ILLEGAL = /(\]\]>)/

    def initialize( first, whitespace=true, parent=nil )
      super( first, whitespace, parent, false, true, ILLEGAL )
    end

    def clone
      CData.new self
    end

    def to_s
      @string
    end

    def value
      @string
    end

    def write( output=$stdout, indent=-1, transitive=false, ie_hack=false )
      Kernel.warn( "#{self.class.name}.write is deprecated" )
      indent( output, indent )
      output << START
      output << @string
      output << STOP
    end
  end
end
