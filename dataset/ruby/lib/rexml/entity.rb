require 'rexml/child'
require 'rexml/source'
require 'rexml/xmltokens'

module REXML
  class Entity < Child
    include XMLTokens
    PUBIDCHAR = "\x20\x0D\x0Aa-zA-Z0-9\\-()+,./:=?;!*@$_%#"
    SYSTEMLITERAL = %Q{((?:"[^"]*")|(?:'[^']*'))}
    PUBIDLITERAL = %Q{("[#{PUBIDCHAR}']*"|'[#{PUBIDCHAR}]*')}
    EXTERNALID = "(?:(?:(SYSTEM)\\s+#{SYSTEMLITERAL})|(?:(PUBLIC)\\s+#{PUBIDLITERAL}\\s+#{SYSTEMLITERAL}))"
    NDATADECL = "\\s+NDATA\\s+#{NAME}"
    PEREFERENCE = "%#{NAME};"
    ENTITYVALUE = %Q{((?:"(?:[^%&"]|#{PEREFERENCE}|#{REFERENCE})*")|(?:'([^%&']|#{PEREFERENCE}|#{REFERENCE})*'))}
    PEDEF = "(?:#{ENTITYVALUE}|#{EXTERNALID})"
    ENTITYDEF = "(?:#{ENTITYVALUE}|(?:#{EXTERNALID}(#{NDATADECL})?))"
    PEDECL = "<!ENTITY\\s+(%)\\s+#{NAME}\\s+#{PEDEF}\\s*>"
    GEDECL = "<!ENTITY\\s+#{NAME}\\s+#{ENTITYDEF}\\s*>"
    ENTITYDECL = /\s*(?:#{GEDECL})|(?:#{PEDECL})/um

    attr_reader :name, :external, :ref, :ndata, :pubid

    def initialize stream, value=nil, parent=nil, reference=false
      super(parent)
      @ndata = @pubid = @value = @external = nil
      if stream.kind_of? Array
        @name = stream[1]
        if stream[-1] == '%'
          @reference = true
          stream.pop
        else
          @reference = false
        end
        if stream[2] =~ /SYSTEM|PUBLIC/
          @external = stream[2]
          if @external == 'SYSTEM'
            @ref = stream[3]
            @ndata = stream[4] if stream.size == 5
          else
            @pubid = stream[3]
            @ref = stream[4]
          end
        else
          @value = stream[2]
        end
      else
        @reference = reference
        @external = nil
        @name = stream
        @value = value
      end
    end

    def Entity::matches? string
      (ENTITYDECL =~ string) == 0
    end

    def unnormalized
      document.record_entity_expansion unless document.nil?
      v = value()
      return nil if v.nil?
      @unnormalized = Text::unnormalize(v, parent)
      @unnormalized
    end


    def normalized
      @value
    end

    def write out, indent=-1
      out << '<!ENTITY '
      out << '% ' if @reference
      out << @name
      out << ' '
      if @external
        out << @external << ' '
        if @pubid
          q = @pubid.include?('"')?"'":'"'
          out << q << @pubid << q << ' '
        end
        q = @ref.include?('"')?"'":'"'
        out << q << @ref << q
        out << ' NDATA ' << @ndata if @ndata
      else
        q = @value.include?('"')?"'":'"'
        out << q << @value << q
      end
      out << '>'
    end

    def to_s
      rv = ''
      write rv
      rv
    end

    PEREFERENCE_RE = /#{PEREFERENCE}/um
    def value
      if @value
        matches = @value.scan(PEREFERENCE_RE)
        rv = @value.clone
        if @parent
          sum = 0
          matches.each do |entity_reference|
            entity_value = @parent.entity( entity_reference[0] )
            if sum + entity_value.bytesize > Security.entity_expansion_text_limit
              raise "entity expansion has grown too large"
            else
              sum += entity_value.bytesize
            end
            rv.gsub!( /%#{entity_reference.join};/um, entity_value )
          end
        end
        return rv
      end
      nil
    end
  end

  module EntityConst
    GT = Entity.new( 'gt', '>' )
    LT = Entity.new( 'lt', '<' )
    AMP = Entity.new( 'amp', '&' )
    QUOT = Entity.new( 'quot', '"' )
    APOS = Entity.new( 'apos', "'" )
  end
end
