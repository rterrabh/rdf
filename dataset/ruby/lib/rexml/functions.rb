module REXML
  module Functions
    @@context = nil
    @@namespace_context = {}
    @@variables = {}

    def Functions::namespace_context=(x) ; @@namespace_context=x ; end
    def Functions::variables=(x) ; @@variables=x ; end
    def Functions::namespace_context ; @@namespace_context ; end
    def Functions::variables ; @@variables ; end

    def Functions::context=(value); @@context = value; end

    def Functions::text( )
      if @@context[:node].node_type == :element
        return @@context[:node].find_all{|n| n.node_type == :text}.collect{|n| n.value}
      elsif @@context[:node].node_type == :text
        return @@context[:node].value
      else
        return false
      end
    end

    def Functions::last( )
      @@context[:size]
    end

    def Functions::position( )
      @@context[:index]
    end

    def Functions::count( node_set )
      node_set.size
    end

    def Functions::id( object )
    end

    def Functions::local_name( node_set=nil )
      get_namespace( node_set ) do |node|
        return node.local_name
      end
    end

    def Functions::namespace_uri( node_set=nil )
      get_namespace( node_set ) {|node| node.namespace}
    end

    def Functions::name( node_set=nil )
      get_namespace( node_set ) do |node|
        node.expanded_name
      end
    end

    def Functions::get_namespace( node_set = nil )
      if node_set == nil
        yield @@context[:node] if defined? @@context[:node].namespace
      else
        if node_set.respond_to? :each
          node_set.each { |node| yield node if defined? node.namespace }
        elsif node_set.respond_to? :namespace
          yield node_set
        end
      end
    end

    def Functions::string( object=nil )
      if object.instance_of? Array
        string( object[0] )
      elsif defined? object.node_type
        if object.node_type == :attribute
          object.value
        elsif object.node_type == :element || object.node_type == :document
          string_value(object)
        else
          object.to_s
        end
      elsif object.nil?
        return ""
      else
        object.to_s
      end
    end

    def Functions::string_value( o )
      rv = ""
      o.children.each { |e|
        if e.node_type == :text
          rv << e.to_s
        elsif e.node_type == :element
          rv << string_value( e )
        end
      }
      rv
    end

    def Functions::concat( *objects )
      objects.join
    end

    def Functions::starts_with( string, test )
      string(string).index(string(test)) == 0
    end

    def Functions::contains( string, test )
      string(string).include?(string(test))
    end

    def Functions::substring_before( string, test )
      ruby_string = string(string)
      ruby_index = ruby_string.index(string(test))
      if ruby_index.nil?
        ""
      else
        ruby_string[ 0...ruby_index ]
      end
    end

    def Functions::substring_after( string, test )
      ruby_string = string(string)
      return $1 if ruby_string =~ /#{test}(.*)/
      ""
    end

    def Functions::substring( string, start, length=nil )
      ruby_string = string(string)
      ruby_length = if length.nil?
                      ruby_string.length.to_f
                    else
                      number(length)
                    end
      ruby_start = number(start)

      return '' if (
        ruby_length.nan? or
        ruby_start.nan? or
        ruby_start.infinite?
      )

      infinite_length = ruby_length.infinite? == 1
      ruby_length = ruby_string.length if infinite_length

      ruby_start = ruby_start.round - 1
      ruby_length = ruby_length.round

      if ruby_start < 0
       ruby_length += ruby_start unless infinite_length
       ruby_start = 0
      end
      return '' if ruby_length <= 0
      ruby_string[ruby_start,ruby_length]
    end

    def Functions::string_length( string )
      string(string).length
    end

    def Functions::normalize_space( string=nil )
      string = string(@@context[:node]) if string.nil?
      if string.kind_of? Array
        string.collect{|x| string.to_s.strip.gsub(/\s+/um, ' ') if string}
      else
        string.to_s.strip.gsub(/\s+/um, ' ')
      end
    end

    def Functions::translate( string, tr1, tr2 )
      from = string(tr1)
      to = string(tr2)


      map = Hash.new
      0.upto(from.length - 1) { |pos|
        from_char = from[pos]
        unless map.has_key? from_char
          map[from_char] =
          if pos < to.length
            to[pos]
          else
            nil
          end
        end
      }

      if ''.respond_to? :chars
        string(string).chars.collect { |c|
          if map.has_key? c then map[c] else c end
        }.compact.join
      else
        string(string).unpack('U*').collect { |c|
          if map.has_key? c then map[c] else c end
        }.compact.pack('U*')
      end
    end

    def Functions::boolean( object=nil )
      if object.kind_of? String
        if object =~ /\d+/u
          return object.to_f != 0
        else
          return object.size > 0
        end
      elsif object.kind_of? Array
        object = object.find{|x| x and true}
      end
      return object ? true : false
    end

    def Functions::not( object )
      not boolean( object )
    end

    def Functions::true( )
      true
    end

    def Functions::false(  )
      false
    end

    def Functions::lang( language )
      lang = false
      node = @@context[:node]
      attr = nil
      until node.nil?
        if node.node_type == :element
          attr = node.attributes["xml:lang"]
          unless attr.nil?
            lang = compare_language(string(language), attr)
            break
          else
          end
        end
        node = node.parent
      end
      lang
    end

    def Functions::compare_language lang1, lang2
      lang2.downcase.index(lang1.downcase) == 0
    end

    def Functions::number( object=nil )
      object = @@context[:node] unless object
      case object
      when true
        Float(1)
      when false
        Float(0)
      when Array
        number(string( object ))
      when Numeric
        object.to_f
      else
        str = string( object )
        if str =~ /^\s*-?(\d*\.?\d+|\d+\.)\s*$/
          str.to_f
        else
          (0.0 / 0.0)
        end
      end
    end

    def Functions::sum( nodes )
      nodes = [nodes] unless nodes.kind_of? Array
      nodes.inject(0) { |r,n| r + number(string(n)) }
    end

    def Functions::floor( number )
      number(number).floor
    end

    def Functions::ceiling( number )
      number(number).ceil
    end

    def Functions::round( number )
      begin
        number(number).round
      rescue FloatDomainError
        number(number)
      end
    end

    def Functions::processing_instruction( node )
      node.node_type == :processing_instruction
    end

    def Functions::method_missing( id )
      puts "METHOD MISSING #{id.id2name}"
      XPath.match( @@context[:node], id.id2name )
    end
  end
end
