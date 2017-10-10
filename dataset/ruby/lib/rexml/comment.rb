require "rexml/child"

module REXML
  class Comment < Child
    include Comparable
    START = "<!--"
    STOP = "-->"


    attr_accessor :string

    def initialize( first, second = nil )
      super(second)
      if first.kind_of? String
        @string = first
      elsif first.kind_of? Comment
        @string = first.string
      end
    end

    def clone
      Comment.new self
    end

    def write( output, indent=-1, transitive=false, ie_hack=false )
      Kernel.warn("Comment.write is deprecated.  See REXML::Formatters")
      indent( output, indent )
      output << START
      output << @string
      output << STOP
    end

    alias :to_s :string

    def <=>(other)
      other.to_s <=> @string
    end

    def ==( other )
      other.kind_of? Comment and
      (other <=> self) == 0
    end

    def node_type
      :comment
    end
  end
end
