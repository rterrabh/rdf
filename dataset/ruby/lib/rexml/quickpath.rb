require 'rexml/functions'
require 'rexml/xmltokens'

module REXML
  class QuickPath
    include Functions
    include XMLTokens

    EMPTY_HASH = {}

    def QuickPath::first element, path, namespaces=EMPTY_HASH
      match(element, path, namespaces)[0]
    end

    def QuickPath::each element, path, namespaces=EMPTY_HASH, &block
      path = "*" unless path
      match(element, path, namespaces).each( &block )
    end

    def QuickPath::match element, path, namespaces=EMPTY_HASH
      raise "nil is not a valid xpath" unless path
      results = nil
      Functions::namespace_context = namespaces
      case path
      when /^\/([^\/]|$)/u
        path = path[1..-1]
        return [element.root.parent] if path == ''
        results = filter([element.root], path)
      when /^[-\w]*::/u
        results = filter([element], path)
      when /^\*/u
        results = filter(element.to_a, path)
      when /^[\[!\w:]/u
        children = element.to_a
        results = filter(children, path)
      else
        results = filter([element], path)
      end
      return results
    end

    def QuickPath::filter elements, path
      return elements if path.nil? or path == '' or elements.size == 0
      case path
      when /^\/\//u                                                                                     # Descendant
        return axe( elements, "descendant-or-self", $' )
      when /^\/?\b(\w[-\w]*)\b::/u                                                      # Axe
        return axe( elements, $1, $' )
      when /^\/(?=\b([:!\w][-\.\w]*:)?[-!\*\.\w]*\b([^:(]|$)|\*)/u      # Child
        rest = $'
        results = []
        elements.each do |element|
          results |= filter( element.to_a, rest )
        end
        return results
      when /^\/?(\w[-\w]*)\(/u                                                  # / Function
        return function( elements, $1, $' )
      when Namespace::NAMESPLIT         # Element name
        name = $2
        ns = $1
        rest = $'
        elements.delete_if do |element|
          !(element.kind_of? Element and
            (element.expanded_name == name or
             (element.name == name and
              element.namespace == Functions.namespace_context[ns])))
        end
        return filter( elements, rest )
      when /^\/\[/u
        matches = []
        elements.each do |element|
          matches |= predicate( element.to_a, path[1..-1] ) if element.kind_of? Element
        end
        return matches
      when /^\[/u                                                                                               # Predicate
        return predicate( elements, path )
      when /^\/?\.\.\./u                                                                                # Ancestor
        return axe( elements, "ancestor", $' )
      when /^\/?\.\./u                                                                                  # Parent
        return filter( elements.collect{|e|e.parent}, $' )
      when /^\/?\./u                                                                                            # Self
        return filter( elements, $' )
      when /^\*/u                                                                                                       # Any
        results = []
        elements.each do |element|
          results |= filter( [element], $' ) if element.kind_of? Element
        end
        return results
      end
      return []
    end

    def QuickPath::axe( elements, axe_name, rest )
      matches = []
      matches = filter( elements.dup, rest ) if axe_name =~ /-or-self$/u
      case axe_name
      when /^descendant/u
        elements.each do |element|
          matches |= filter( element.to_a, "descendant-or-self::#{rest}" ) if element.kind_of? Element
        end
      when /^ancestor/u
        elements.each do |element|
          while element.parent
            matches << element.parent
            element = element.parent
          end
        end
        matches = filter( matches, rest )
      when "self"
        matches = filter( elements, rest )
      when "child"
        elements.each do |element|
          matches |= filter( element.to_a, rest ) if element.kind_of? Element
        end
      when "attribute"
        elements.each do |element|
          matches << element.attributes[ rest ] if element.kind_of? Element
        end
      when "parent"
        matches = filter(elements.collect{|element| element.parent}.uniq, rest)
      when "following-sibling"
        matches = filter(elements.collect{|element| element.next_sibling}.uniq,
          rest)
      when "previous-sibling"
        matches = filter(elements.collect{|element|
          element.previous_sibling}.uniq, rest )
      end
      return matches.uniq
    end

    OPERAND_ = '((?=(?:(?!and|or).)*[^\s<>=])[^\s<>=]+)'
    def QuickPath::predicate( elements, path )
      ind = 1
      bcount = 1
      while bcount > 0
        bcount += 1 if path[ind] == ?[
        bcount -= 1 if path[ind] == ?]
        ind += 1
      end
      ind -= 1
      predicate = path[1..ind-1]
      rest = path[ind+1..-1]

      predicate.gsub!(
        /#{OPERAND_}\s*([<>=])\s*#{OPERAND_}\s*([<>=])\s*#{OPERAND_}/u,
        '\1 \2 \3 and \3 \4 \5' )
      predicate.gsub!( /&/u, "&&" )
      predicate.gsub!( /=/u, "==" )
      predicate.gsub!( /@(\w[-\w.]*)/u, 'attribute("\1")' )
      predicate.gsub!( /\bmod\b/u, "%" )
      predicate.gsub!( /\b(\w[-\w.]*\()/u ) {
        fname = $1
        fname.gsub( /-/u, "_" )
      }

      Functions.pair = [ 0, elements.size ]
      results = []
      elements.each do |element|
        Functions.pair[0] += 1
        Functions.node = element
        #nodyna <eval-1983> <EV COMPLEX (change-prone variables)>
        res = eval( predicate )
        case res
        when true
          results << element
        when Fixnum
          results << element if Functions.pair[0] == res
        when String
          results << element
        end
      end
      return filter( results, rest )
    end

    def QuickPath::attribute( name )
      return Functions.node.attributes[name] if Functions.node.kind_of? Element
    end

    def QuickPath::name()
      return Functions.node.name if Functions.node.kind_of? Element
    end

    def QuickPath::method_missing( id, *args )
      begin
        #nodyna <send-1984> <SD COMPLEX (change-prone variables)>
        Functions.send( id.id2name, *args )
      rescue Exception
        raise "METHOD: #{id.id2name}(#{args.join ', '})\n#{$!.message}"
      end
    end

    def QuickPath::function( elements, fname, rest )
      args = parse_args( elements, rest )
      Functions.pair = [0, elements.size]
      results = []
      elements.each do |element|
        Functions.pair[0] += 1
        Functions.node = element
        #nodyna <send-1985> <SD COMPLEX (change-prone variables)>
        res = Functions.send( fname, *args )
        case res
        when true
          results << element
        when Fixnum
          results << element if Functions.pair[0] == res
        end
      end
      return results
    end

    def QuickPath::parse_args( element, string )
      arguments = []
      buffer = ""
      while string and string != ""
        c = string[0]
        string.sub!(/^./u, "")
        case c
        when ?,
          arguments << evaluate( buffer )
        when ?(
          function( element, buffer, string )
          buffer = ""
        when ?)
          return arguments
        else
          buffer << c
        end
      end
      ""
    end
  end
end
