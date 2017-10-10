require "rexml/parent"
require "rexml/parseexception"
require "rexml/namespace"
require 'rexml/entity'
require 'rexml/attlistdecl'
require 'rexml/xmltokens'

module REXML
  class DocType < Parent
    include XMLTokens
    START = "<!DOCTYPE"
    STOP = ">"
    SYSTEM = "SYSTEM"
    PUBLIC = "PUBLIC"
    DEFAULT_ENTITIES = {
      'gt'=>EntityConst::GT,
      'lt'=>EntityConst::LT,
      'quot'=>EntityConst::QUOT,
      "apos"=>EntityConst::APOS
    }

    attr_reader :name, :external_id, :entities, :namespaces

    def initialize( first, parent=nil )
      @entities = DEFAULT_ENTITIES
      @long_name = @uri = nil
      if first.kind_of? String
        super()
        @name = first
        @external_id = parent
      elsif first.kind_of? DocType
        super( parent )
        @name = first.name
        @external_id = first.external_id
      elsif first.kind_of? Array
        super( parent )
        @name = first[0]
        @external_id = first[1]
        @long_name = first[2]
        @uri = first[3]
      elsif first.kind_of? Source
        super( parent )
        parser = Parsers::BaseParser.new( first )
        event = parser.pull
        if event[0] == :start_doctype
          @name, @external_id, @long_name, @uri, = event[1..-1]
        end
      else
        super()
      end
    end

    def node_type
      :doctype
    end

    def attributes_of element
      rv = []
      each do |child|
        child.each do |key,val|
          rv << Attribute.new(key,val)
        end if child.kind_of? AttlistDecl and child.element_name == element
      end
      rv
    end

    def attribute_of element, attribute
      att_decl = find do |child|
        child.kind_of? AttlistDecl and
        child.element_name == element and
        child.include? attribute
      end
      return nil unless att_decl
      att_decl[attribute]
    end

    def clone
      DocType.new self
    end

    def write( output, indent=0, transitive=false, ie_hack=false )
      f = REXML::Formatters::Default.new
      indent( output, indent )
      output << START
      output << ' '
      output << @name
      output << " #@external_id" if @external_id
      output << " #{@long_name.inspect}" if @long_name
      output << " #{@uri.inspect}" if @uri
      unless @children.empty?
        output << ' ['
        @children.each { |child|
          output << "\n"
          f.write( child, output )
        }
        output << "\n]"
      end
      output << STOP
    end

    def context
      @parent.context
    end

    def entity( name )
      @entities[name].unnormalized if @entities[name]
    end

    def add child
      super(child)
      @entities = DEFAULT_ENTITIES.clone if @entities == DEFAULT_ENTITIES
      @entities[ child.name ] = child if child.kind_of? Entity
    end

    def public
      case @external_id
      when "SYSTEM"
        nil
      when "PUBLIC"
        strip_quotes(@long_name)
      end
    end

    def system
      case @external_id
      when "SYSTEM"
        strip_quotes(@long_name)
      when "PUBLIC"
        @uri.kind_of?(String) ? strip_quotes(@uri) : nil
      end
    end

    def notations
      children().select {|node| node.kind_of?(REXML::NotationDecl)}
    end

    def notation(name)
      notations.find { |notation_decl|
        notation_decl.name == name
      }
    end

    private

    def strip_quotes(quoted_string)
      quoted_string =~ /^[\'\"].*[\'\"]$/ ?
        quoted_string[1, quoted_string.length-2] :
        quoted_string
    end
  end


  class Declaration < Child
    def initialize src
      super()
      @string = src
    end

    def to_s
      @string+'>'
    end

    def write( output, indent )
      output << to_s
    end
  end

  public
  class ElementDecl < Declaration
    def initialize( src )
      super
    end
  end

  class ExternalEntity < Child
    def initialize( src )
      super()
      @entity = src
    end
    def to_s
      @entity
    end
    def write( output, indent )
      output << @entity
    end
  end

  class NotationDecl < Child
    attr_accessor :public, :system
    def initialize name, middle, pub, sys
      super(nil)
      @name = name
      @middle = middle
      @public = pub
      @system = sys
    end

    def to_s
      notation = "<!NOTATION #{@name} #{@middle}"
      notation << " #{@public.inspect}" if @public
      notation << " #{@system.inspect}" if @system
      notation << ">"
      notation
    end

    def write( output, indent=-1 )
      output << to_s
    end

    def name
      @name
    end
  end
end
