
class RDoc::CrossReference


  CLASS_REGEXP_STR = '\\\\?((?:\:{2})?[A-Z]\w*(?:\:\:\w+)*)'


  METHOD_REGEXP_STR = '([a-z]\w*[!?=]?|%|===|\[\]=?|<<|>>)(?:\([\w.+*/=<>-]*\))?'


  CROSSREF_REGEXP = /(?:^|\s)
                     (
                      (?:

                       | \\?\##{METHOD_REGEXP_STR}

                       | ::#{METHOD_REGEXP_STR}

                       | #{CLASS_REGEXP_STR}(?=[@\s).?!,;<\000]|\z)

                       | (?:\.\.\/)*[-\/\w]+[_\/.][-\w\/.]+

                       | \\[^\s<]
                      )

                      (?:@[\w+%-]+(?:\.[\w|%-]+)?)?
                     )/x


  ALL_CROSSREF_REGEXP = /
                     (?:^|\s)
                     (
                      (?:

                       | \\?#{METHOD_REGEXP_STR}

                       | #{CLASS_REGEXP_STR}(?=[@\s).?!,;<\000]|\z)

                       | (?:\.\.\/)*[-\/\w]+[_\/.][-\w\/.]+

                       | \\[^\s<]
                      )

                      (?:@[\w+%-]+)?
                     )/x


  attr_accessor :seen


  def initialize context
    @context = context
    @store   = context.store

    @seen = {}
  end


  def resolve name, text
    return @seen[name] if @seen.include? name

    if /#{CLASS_REGEXP_STR}([.#]|::)#{METHOD_REGEXP_STR}/o =~ name then
      type = $2
      type = '' if type == '.'  # will find either #method or ::method
      method = "#{type}#{$3}"
      container = @context.find_symbol_module($1)
    elsif /^([.#]|::)#{METHOD_REGEXP_STR}/o =~ name then
      type = $1
      type = '' if type == '.'
      method = "#{type}#{$2}"
      container = @context
    else
      container = nil
    end

    if container then
      ref = container.find_local_symbol method

      unless ref || RDoc::TopLevel === container then
        ref = container.find_ancestor_local_symbol method
      end
    end

    ref = case name
          when /^\\(#{CLASS_REGEXP_STR})$/o then
            @context.find_symbol $1
          else
            @context.find_symbol name
          end unless ref

    ref = @store.page name if not ref and name =~ /^\w+$/

    ref = nil if RDoc::Alias === ref # external alias, can't link to it

    out = if name == '\\' then
            name
          elsif name =~ /^\\/ then
            ref ? $' : name
          elsif ref then
            if ref.display? then
              ref
            else
              text
            end
          else
            text
          end

    @seen[name] = out

    out
  end

end

