require "rexml/security"
require "rexml/element"
require "rexml/xmldecl"
require "rexml/source"
require "rexml/comment"
require "rexml/doctype"
require "rexml/instruction"
require "rexml/rexml"
require "rexml/parseexception"
require "rexml/output"
require "rexml/parsers/baseparser"
require "rexml/parsers/streamparser"
require "rexml/parsers/treeparser"

module REXML
  class Document < Element
    DECLARATION = XMLDecl.default

    def initialize( source = nil, context = {} )
      @entity_expansion_count = 0
      super()
      @context = context
      return if source.nil?
      if source.kind_of? Document
        @context = source.context
        super source
      else
        build(  source )
      end
    end

    def node_type
      :document
    end

    def clone
      Document.new self
    end

    def expanded_name
      ''
    end

    alias :name :expanded_name

    def add( child )
      if child.kind_of? XMLDecl
        if @children[0].kind_of? XMLDecl
          @children[0] = child
        else
          @children.unshift child
        end
        child.parent = self
      elsif child.kind_of? DocType
        insert_before_index = @children.find_index { |x|
          x.kind_of?(Element) || x.kind_of?(DocType)
        }
        if insert_before_index # Not null = not end of list
          if @children[ insert_before_index ].kind_of? DocType
            @children[ insert_before_index ] = child
          else
            @children[ insert_before_index-1, 0 ] = child
          end
        else  # Insert at end of list
          @children << child
        end
        child.parent = self
      else
        rv = super
        raise "attempted adding second root element to document" if @elements.size > 1
        rv
      end
    end
    alias :<< :add

    def add_element(arg=nil, arg2=nil)
      rv = super
      raise "attempted adding second root element to document" if @elements.size > 1
      rv
    end

    def root
      elements[1]
    end

    def doctype
      @children.find { |item| item.kind_of? DocType }
    end

    def xml_decl
      rv = @children[0]
      return rv if rv.kind_of? XMLDecl
      @children.unshift(XMLDecl.default)[0]
    end

    def version
      xml_decl().version
    end

    def encoding
      xml_decl().encoding
    end

    def stand_alone?
      xml_decl().stand_alone?
    end

    def write(*arguments)
      if arguments.size == 1 and arguments[0].class == Hash
        options = arguments[0]

        output     = options[:output]
        indent     = options[:indent]
        transitive = options[:transitive]
        ie_hack    = options[:ie_hack]
        encoding   = options[:encoding]
      else
        output, indent, transitive, ie_hack, encoding, = *arguments
      end

      output   ||= $stdout
      indent   ||= -1
      transitive = false if transitive.nil?
      ie_hack    = false if ie_hack.nil?
      encoding ||= xml_decl.encoding

      if encoding != 'UTF-8' && !output.kind_of?(Output)
        output = Output.new( output, encoding )
      end
      formatter = if indent > -1
          if transitive
            require "rexml/formatters/transitive"
            REXML::Formatters::Transitive.new( indent, ie_hack )
          else
            REXML::Formatters::Pretty.new( indent, ie_hack )
          end
        else
          REXML::Formatters::Default.new( ie_hack )
        end
      formatter.write( self, output )
    end


    def Document::parse_stream( source, listener )
      Parsers::StreamParser.new( source, listener ).parse
    end

    def Document::entity_expansion_limit=( val )
      Security.entity_expansion_limit = val
    end

    def Document::entity_expansion_limit
      return Security.entity_expansion_limit
    end

    def Document::entity_expansion_text_limit=( val )
      Security.entity_expansion_text_limit = val
    end

    def Document::entity_expansion_text_limit
      return Security.entity_expansion_text_limit
    end

    attr_reader :entity_expansion_count

    def record_entity_expansion
      @entity_expansion_count += 1
      if @entity_expansion_count > Security.entity_expansion_limit
        raise "number of entity expansions exceeded, processing aborted."
      end
    end

    def document
      self
    end

    private
    def build( source )
      Parsers::TreeParser.new( source, self ).parse
    end
  end
end
