require "rexml/child"
require "rexml/source"

module REXML
  class Instruction < Child
    START = '<\?'
    STOP = '\?>'

    attr_accessor :target, :content

    def initialize(target, content=nil)
      if target.kind_of? String
        super()
        @target = target
        @content = content
      elsif target.kind_of? Instruction
        super(content)
        @target = target.target
        @content = target.content
      end
      @content.strip! if @content
    end

    def clone
      Instruction.new self
    end

    def write writer, indent=-1, transitive=false, ie_hack=false
      Kernel.warn( "#{self.class.name}.write is deprecated" )
      indent(writer, indent)
      writer << START.sub(/\\/u, '')
      writer << @target
      writer << ' '
      writer << @content
      writer << STOP.sub(/\\/u, '')
    end

    def ==( other )
      other.kind_of? Instruction and
      other.target == @target and
      other.content == @content
    end

    def node_type
      :processing_instruction
    end

    def inspect
      "<?p-i #{target} ...?>"
    end
  end
end
