require "rexml/parent"
require "rexml/namespace"
require "rexml/attribute"
require "rexml/cdata"
require "rexml/xpath"
require "rexml/parseexception"

module REXML
  @@namespaces = {}

  class Element < Parent
    include Namespace

    UNDEFINED = "UNDEFINED";            # The default name

    attr_reader :attributes, :elements
    attr_accessor :context

    def initialize( arg = UNDEFINED, parent=nil, context=nil )
      super(parent)

      @elements = Elements.new(self)
      @attributes = Attributes.new(self)
      @context = context

      if arg.kind_of? String
        self.name = arg
      elsif arg.kind_of? Element
        self.name = arg.expanded_name
        arg.attributes.each_attribute{ |attribute|
          @attributes << Attribute.new( attribute )
        }
        @context = arg.context
      end
    end

    def inspect
      rv = "<#@expanded_name"

      @attributes.each_attribute do |attr|
        rv << " "
        attr.write( rv, 0 )
      end

      if children.size > 0
        rv << "> ... </>"
      else
        rv << "/>"
      end
    end


    def clone
      self.class.new self
    end

    def root_node
      parent.nil? ? self : parent.root_node
    end

    def root
      return elements[1] if self.kind_of? Document
      return self if parent.kind_of? Document or parent.nil?
      return parent.root
    end

    def document
      rt = root
      rt.parent if rt
    end

    def whitespace
      @whitespace = nil
      if @context
        if @context[:respect_whitespace]
          @whitespace = (@context[:respect_whitespace] == :all or
                         @context[:respect_whitespace].include? expanded_name)
        end
        @whitespace = false if (@context[:compress_whitespace] and
                                (@context[:compress_whitespace] == :all or
                                 @context[:compress_whitespace].include? expanded_name)
                               )
      end
      @whitespace = true unless @whitespace == false
      @whitespace
    end

    def ignore_whitespace_nodes
      @ignore_whitespace_nodes = false
      if @context
        if @context[:ignore_whitespace_nodes]
          @ignore_whitespace_nodes =
            (@context[:ignore_whitespace_nodes] == :all or
             @context[:ignore_whitespace_nodes].include? expanded_name)
        end
      end
    end

    def raw
      @raw = (@context and @context[:raw] and
              (@context[:raw] == :all or
               @context[:raw].include? expanded_name))
               @raw
    end



    def prefixes
      prefixes = []
      prefixes = parent.prefixes if parent
      prefixes |= attributes.prefixes
      return prefixes
    end

    def namespaces
      namespaces = {}
      namespaces = parent.namespaces if parent
      namespaces = namespaces.merge( attributes.namespaces )
      return namespaces
    end

    def namespace(prefix=nil)
      if prefix.nil?
        prefix = prefix()
      end
      if prefix == ''
        prefix = "xmlns"
      else
        prefix = "xmlns:#{prefix}" unless prefix[0,5] == 'xmlns'
      end
      ns = attributes[ prefix ]
      ns = parent.namespace(prefix) if ns.nil? and parent
      ns = '' if ns.nil? and prefix == 'xmlns'
      return ns
    end

    def add_namespace( prefix, uri=nil )
      unless uri
        @attributes["xmlns"] = prefix
      else
        prefix = "xmlns:#{prefix}" unless prefix =~ /^xmlns:/
        @attributes[ prefix ] = uri
      end
      self
    end

    def delete_namespace namespace="xmlns"
      namespace = "xmlns:#{namespace}" unless namespace == 'xmlns'
      attribute = attributes.get_attribute(namespace)
      attribute.remove unless attribute.nil?
      self
    end


    def add_element element, attrs=nil
      raise "First argument must be either an element name, or an Element object" if element.nil?
      el = @elements.add(element)
      attrs.each do |key, value|
        el.attributes[key]=value
      end       if attrs.kind_of? Hash
      el
    end

    def delete_element element
      @elements.delete element
    end

    def has_elements?
      !@elements.empty?
    end

    def each_element_with_attribute( key, value=nil, max=0, name=nil, &block ) # :yields: Element
      each_with_something( proc {|child|
        if value.nil?
          child.attributes[key] != nil
        else
          child.attributes[key]==value
        end
      }, max, name, &block )
    end

    def each_element_with_text( text=nil, max=0, name=nil, &block ) # :yields: Element
      each_with_something( proc {|child|
        if text.nil?
          child.has_text?
        else
          child.text == text
        end
      }, max, name, &block )
    end

    def each_element( xpath=nil, &block ) # :yields: Element
      @elements.each( xpath, &block )
    end

    def get_elements( xpath )
      @elements.to_a( xpath )
    end

    def next_element
      element = next_sibling
      element = element.next_sibling until element.nil? or element.kind_of? Element
      return element
    end

    def previous_element
      element = previous_sibling
      element = element.previous_sibling until element.nil? or element.kind_of? Element
      return element
    end



    def has_text?
      not text().nil?
    end

    def text( path = nil )
      rv = get_text(path)
      return rv.value unless rv.nil?
      nil
    end

    def get_text path = nil
      rv = nil
      if path
        element = @elements[ path ]
        rv = element.get_text unless element.nil?
      else
        rv = @children.find { |node| node.kind_of? Text }
      end
      return rv
    end

    def text=( text )
      if text.kind_of? String
        text = Text.new( text, whitespace(), nil, raw() )
      elsif !text.nil? and !text.kind_of? Text
        text = Text.new( text.to_s, whitespace(), nil, raw() )
      end
      old_text = get_text
      if text.nil?
        old_text.remove unless old_text.nil?
      else
        if old_text.nil?
          self << text
        else
          old_text.replace_with( text )
        end
      end
      return self
    end

    def add_text( text )
      if text.kind_of? String
        if @children[-1].kind_of? Text
          @children[-1] << text
          return
        end
        text = Text.new( text, whitespace(), nil, raw() )
      end
      self << text unless text.nil?
      return self
    end

    def node_type
      :element
    end

    def xpath
      path_elements = []
      cur = self
      path_elements << __to_xpath_helper( self )
      while cur.parent
        cur = cur.parent
        path_elements << __to_xpath_helper( cur )
      end
      return path_elements.reverse.join( "/" )
    end


    def attribute( name, namespace=nil )
      prefix = nil
      if namespaces.respond_to? :key
        prefix = namespaces.key(namespace) if namespace
      else
        prefix = namespaces.index(namespace) if namespace
      end
      prefix = nil if prefix == 'xmlns'

      ret_val =
        attributes.get_attribute( "#{prefix ? prefix + ':' : ''}#{name}" )

      return ret_val unless ret_val.nil?
      return nil if prefix.nil?

      return nil unless ( namespaces[ prefix ] == namespaces[ 'xmlns' ] )

      attributes.get_attribute( name )

    end

    def has_attributes?
      return !@attributes.empty?
    end

    def add_attribute( key, value=nil )
      if key.kind_of? Attribute
        @attributes << key
      else
        @attributes[key] = value
      end
    end

    def add_attributes hash
      if hash.kind_of? Hash
        hash.each_pair {|key, value| @attributes[key] = value }
      elsif hash.kind_of? Array
        hash.each { |value| @attributes[ value[0] ] = value[1] }
      end
    end

    def delete_attribute(key)
      attr = @attributes.get_attribute(key)
      attr.remove unless attr.nil?
    end


    def cdatas
      find_all { |child| child.kind_of? CData }.freeze
    end

    def comments
      find_all { |child| child.kind_of? Comment }.freeze
    end

    def instructions
      find_all { |child| child.kind_of? Instruction }.freeze
    end

    def texts
      find_all { |child| child.kind_of? Text }.freeze
    end

    def write(output=$stdout, indent=-1, transitive=false, ie_hack=false)
      Kernel.warn("#{self.class.name}.write is deprecated.  See REXML::Formatters")
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


    private
    def __to_xpath_helper node
      rv = node.expanded_name.clone
      if node.parent
        results = node.parent.find_all {|n|
          n.kind_of?(REXML::Element) and n.expanded_name == node.expanded_name
        }
        if results.length > 1
          idx = results.index( node )
          rv << "[#{idx+1}]"
        end
      end
      rv
    end

    def each_with_something( test, max=0, name=nil )
      num = 0
      @elements.each( name ){ |child|
        yield child if test.call(child) and num += 1
        return if max>0 and num == max
      }
    end
  end


  class Elements
    include Enumerable
    def initialize parent
      @element = parent
    end

    def []( index, name=nil)
      if index.kind_of? Integer
        raise "index (#{index}) must be >= 1" if index < 1
        name = literalize(name) if name
        num = 0
        @element.find { |child|
          child.kind_of? Element and
          (name.nil? ? true : child.has_name?( name )) and
          (num += 1) == index
        }
      else
        return XPath::first( @element, index )
      end
    end

    def []=( index, element )
      previous = self[index]
      if previous.nil?
        @element.add element
      else
        previous.replace_with element
      end
      return previous
    end

    def empty?
      @element.find{ |child| child.kind_of? Element}.nil?
    end

    def index element
      rv = 0
      found = @element.find do |child|
        child.kind_of? Element and
        (rv += 1) and
        child == element
      end
      return rv if found == element
      return -1
    end

    def delete element
      if element.kind_of? Element
        @element.delete element
      else
        el = self[element]
        el.remove if el
      end
    end

    def delete_all( xpath )
      rv = []
      XPath::each( @element, xpath) {|element|
        rv << element if element.kind_of? Element
      }
      rv.each do |element|
        @element.delete element
        element.remove
      end
      return rv
    end

    def add element=nil
      if element.nil?
        Element.new("", self, @element.context)
      elsif not element.kind_of?(Element)
        Element.new(element, self, @element.context)
      else
        @element << element
        element.context = @element.context
        element
      end
    end

    alias :<< :add

    def each( xpath=nil )
      XPath::each( @element, xpath ) {|e| yield e if e.kind_of? Element }
    end

    def collect( xpath=nil )
      collection = []
      XPath::each( @element, xpath ) {|e|
        collection << yield(e)  if e.kind_of?(Element)
      }
      collection
    end

    def inject( xpath=nil, initial=nil )
      first = true
      XPath::each( @element, xpath ) {|e|
        if (e.kind_of? Element)
          if (first and initial == nil)
            initial = e
            first = false
          else
            initial = yield( initial, e ) if e.kind_of? Element
          end
        end
      }
      initial
    end

    def size
      count = 0
      @element.each {|child| count+=1 if child.kind_of? Element }
      count
    end

    def to_a( xpath=nil )
      rv = XPath.match( @element, xpath )
      return rv.find_all{|e| e.kind_of? Element} if xpath
      rv
    end

    private
    def literalize name
      name = name[1..-2] if name[0] == ?' or name[0] == ?"               #'
      name
    end
  end


  class Attributes < Hash
    def initialize element
      @element = element
    end

    def [](name)
      attr = get_attribute(name)
      return attr.value unless attr.nil?
      return nil
    end

    def to_a
      enum_for(:each_attribute).to_a
    end

    def length
      c = 0
      each_attribute { c+=1 }
      c
    end
    alias :size :length

    def each_attribute # :yields: attribute
      each_value do |val|
        if val.kind_of? Attribute
          yield val
        else
          val.each_value { |atr| yield atr }
        end
      end
    end

    def each
      each_attribute do |attr|
        yield [attr.expanded_name, attr.value]
      end
    end

    def get_attribute( name )
      attr = fetch( name, nil )
      if attr.nil?
        return nil if name.nil?
        name =~ Namespace::NAMESPLIT
        prefix, n = $1, $2
        if prefix
          attr = fetch( n, nil )
          if attr == nil
          elsif attr.kind_of? Attribute
            return attr if prefix == attr.prefix
          else
            attr = attr[ prefix ]
            return attr
          end
        end
        element_document = @element.document
        if element_document and element_document.doctype
          expn = @element.expanded_name
          expn = element_document.doctype.name if expn.size == 0
          attr_val = element_document.doctype.attribute_of(expn, name)
          return Attribute.new( name, attr_val ) if attr_val
        end
        return nil
      end
      if attr.kind_of? Hash
        attr = attr[ @element.prefix ]
      end
      return attr
    end

    def []=( name, value )
      if value.nil?             # Delete the named attribute
        attr = get_attribute(name)
        delete attr
        return
      end

      unless value.kind_of? Attribute
        if @element.document and @element.document.doctype
          value = Text::normalize( value, @element.document.doctype )
        else
          value = Text::normalize( value, nil )
        end
        value = Attribute.new(name, value)
      end
      value.element = @element
      old_attr = fetch(value.name, nil)
      if old_attr.nil?
        store(value.name, value)
      elsif old_attr.kind_of? Hash
        old_attr[value.prefix] = value
      elsif old_attr.prefix != value.prefix
        raise ParseException.new(
          "Namespace conflict in adding attribute \"#{value.name}\": "+
          "Prefix \"#{old_attr.prefix}\" = "+
          "\"#{@element.namespace(old_attr.prefix)}\" and prefix "+
          "\"#{value.prefix}\" = \"#{@element.namespace(value.prefix)}\"") if
          value.prefix != "xmlns" and old_attr.prefix != "xmlns" and
          @element.namespace( old_attr.prefix ) ==
            @element.namespace( value.prefix )
          store value.name, { old_attr.prefix   => old_attr,
            value.prefix                => value }
      else
        store value.name, value
      end
      return @element
    end

    def prefixes
      ns = []
      each_attribute do |attribute|
        ns << attribute.name if attribute.prefix == 'xmlns'
      end
      if @element.document and @element.document.doctype
        expn = @element.expanded_name
        expn = @element.document.doctype.name if expn.size == 0
        @element.document.doctype.attributes_of(expn).each {
          |attribute|
          ns << attribute.name if attribute.prefix == 'xmlns'
        }
      end
      ns
    end

    def namespaces
      namespaces = {}
      each_attribute do |attribute|
        namespaces[attribute.name] = attribute.value if attribute.prefix == 'xmlns' or attribute.name == 'xmlns'
      end
      if @element.document and @element.document.doctype
        expn = @element.expanded_name
        expn = @element.document.doctype.name if expn.size == 0
        @element.document.doctype.attributes_of(expn).each {
          |attribute|
          namespaces[attribute.name] = attribute.value if attribute.prefix == 'xmlns' or attribute.name == 'xmlns'
        }
      end
      namespaces
    end

    def delete( attribute )
      name = nil
      prefix = nil
      if attribute.kind_of? Attribute
        name = attribute.name
        prefix = attribute.prefix
      else
        attribute =~ Namespace::NAMESPLIT
        prefix, name = $1, $2
        prefix = '' unless prefix
      end
      old = fetch(name, nil)
      if old.kind_of? Hash # the supplied attribute is one of many
        old.delete(prefix)
        if old.size == 1
          repl = nil
          old.each_value{|v| repl = v}
          store name, repl
        end
      elsif old.nil?
        return @element
      else # the supplied attribute is a top-level one
        super(name)
      end
      @element
    end

    def add( attribute )
      self[attribute.name] = attribute
    end

    alias :<< :add

    def delete_all( name )
      rv = []
      each_attribute { |attribute|
        rv << attribute if attribute.expanded_name == name
      }
      rv.each{ |attr| attr.remove }
      return rv
    end

    def get_attribute_ns(namespace, name)
      result = nil
      each_attribute() { |attribute|
        if name == attribute.name &&
          namespace == attribute.namespace() &&
          ( !namespace.empty? || !attribute.fully_expanded_name.index(':') )
          result = attribute if !result or !namespace.empty? or
                                !attribute.fully_expanded_name.index(':')
        end
      }
      result
    end
  end
end
