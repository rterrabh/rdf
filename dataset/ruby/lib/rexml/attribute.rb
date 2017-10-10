require "rexml/namespace"
require 'rexml/text'

module REXML
  class Attribute
    include Node
    include Namespace

    attr_reader :element
    attr_writer :normalized
    PATTERN = /\s*(#{NAME_STR})\s*=\s*(["'])(.*?)\2/um

    NEEDS_A_SECOND_CHECK = /(<|&((#{Entity::NAME});|(#0*((?:\d+)|(?:x[a-fA-F0-9]+)));)?)/um

    def initialize( first, second=nil, parent=nil )
      @normalized = @unnormalized = @element = nil
      if first.kind_of? Attribute
        self.name = first.expanded_name
        @unnormalized = first.value
        if second.kind_of? Element
          @element = second
        else
          @element = first.element
        end
      elsif first.kind_of? String
        @element = parent
        self.name = first
        @normalized = second.to_s
      else
        raise "illegal argument #{first.class.name} to Attribute constructor"
      end
    end

    def prefix
      pf = super
      if pf == ""
        pf = @element.prefix if @element
      end
      pf
    end

    def namespace arg=nil
      arg = prefix if arg.nil?
      @element.namespace arg
    end

    def ==( other )
      other.kind_of?(Attribute) and other.name==name and other.value==value
    end

    def hash
      name.hash + value.hash
    end

    def to_string
      if @element and @element.context and @element.context[:attribute_quote] == :quote
        %Q^#@expanded_name="#{to_s().gsub(/"/, '&quote;')}"^
      else
        "#@expanded_name='#{to_s().gsub(/'/, '&apos;')}'"
      end
    end

    def doctype
      if @element
        doc = @element.document
        doc.doctype if doc
      end
    end

    def to_s
      return @normalized if @normalized

      @normalized = Text::normalize( @unnormalized, doctype )
      @unnormalized = nil
      @normalized
    end

    def value
      return @unnormalized if @unnormalized
      @unnormalized = Text::unnormalize( @normalized, doctype )
      @normalized = nil
      @unnormalized
    end

    def clone
      Attribute.new self
    end

    def element=( element )
      @element = element

      if @normalized
        Text.check( @normalized, NEEDS_A_SECOND_CHECK, doctype )
      end

      self
    end

    def remove
      @element.attributes.delete self.name unless @element.nil?
    end

    def write( output, indent=-1 )
      output << to_string
    end

    def node_type
      :attribute
    end

    def inspect
      rv = ""
      write( rv )
      rv
    end

    def xpath
      path = @element.xpath
      path += "/@#{self.expanded_name}"
      return path
    end
  end
end
