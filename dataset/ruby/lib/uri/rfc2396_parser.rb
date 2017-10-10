
module URI
  module RFC2396_REGEXP
    module PATTERN


      ALPHA = "a-zA-Z"
      ALNUM = "#{ALPHA}\\d"

      HEX     = "a-fA-F\\d"
      ESCAPED = "%[#{HEX}]{2}"
      UNRESERVED = "\\-_.!~*'()#{ALNUM}"
      RESERVED = ";/?:@&=+$,\\[\\]"

      DOMLABEL = "(?:[#{ALNUM}](?:[-#{ALNUM}]*[#{ALNUM}])?)"
      TOPLABEL = "(?:[#{ALPHA}](?:[-#{ALNUM}]*[#{ALNUM}])?)"
      HOSTNAME = "(?:#{DOMLABEL}\\.)*#{TOPLABEL}\\.?"

    end # PATTERN

  end # REGEXP

  class RFC2396_Parser
    include RFC2396_REGEXP

    def initialize(opts = {})
      @pattern = initialize_pattern(opts)
      @pattern.each_value(&:freeze)
      @pattern.freeze

      @regexp = initialize_regexp(@pattern)
      @regexp.each_value(&:freeze)
      @regexp.freeze
    end

    attr_reader :pattern

    attr_reader :regexp

    def split(uri)
      case uri
      when ''

      when @regexp[:ABS_URI]
        scheme, opaque, userinfo, host, port,
          registry, path, query, fragment = $~[1..-1]





        if !scheme
          raise InvalidURIError,
            "bad URI(absolute but no scheme): #{uri}"
        end
        if !opaque && (!path && (!host && !registry))
          raise InvalidURIError,
            "bad URI(absolute but no path): #{uri}"
        end

      when @regexp[:REL_URI]
        scheme = nil
        opaque = nil

        userinfo, host, port, registry,
          rel_segment, abs_path, query, fragment = $~[1..-1]
        if rel_segment && abs_path
          path = rel_segment + abs_path
        elsif rel_segment
          path = rel_segment
        elsif abs_path
          path = abs_path
        end





      else
        raise InvalidURIError, "bad URI(is not URI?): #{uri}"
      end

      path = '' if !path && !opaque # (see RFC2396 Section 5.2)
      ret = [
        scheme,
        userinfo, host, port,         # X
        registry,                     # X
        path,                         # Y
        opaque,                       # Y
        query,
        fragment
      ]
      return ret
    end

    def parse(uri)
      scheme, userinfo, host, port,
        registry, path, opaque, query, fragment = self.split(uri)

      if scheme && URI.scheme_list.include?(scheme.upcase)
        URI.scheme_list[scheme.upcase].new(scheme, userinfo, host, port,
                                           registry, path, opaque, query,
                                           fragment, self)
      else
        Generic.new(scheme, userinfo, host, port,
                    registry, path, opaque, query,
                    fragment, self)
      end
    end


    def join(*uris)
      uris[0] = convert_to_uri(uris[0])
      uris.inject :merge
    end

    def extract(str, schemes = nil)
      if block_given?
        str.scan(make_regexp(schemes)) { yield $& }
        nil
      else
        result = []
        str.scan(make_regexp(schemes)) { result.push $& }
        result
      end
    end

    def make_regexp(schemes = nil)
      unless schemes
        @regexp[:ABS_URI_REF]
      else
        /(?=#{Regexp.union(*schemes)}:)#{@pattern[:X_ABS_URI]}/x
      end
    end

    def escape(str, unsafe = @regexp[:UNSAFE])
      unless unsafe.kind_of?(Regexp)
        unsafe = Regexp.new("[#{Regexp.quote(unsafe)}]", false)
      end
      str.gsub(unsafe) do
        us = $&
        tmp = ''
        us.each_byte do |uc|
          tmp << sprintf('%%%02X', uc)
        end
        tmp
      end.force_encoding(Encoding::US_ASCII)
    end

    def unescape(str, escaped = @regexp[:ESCAPED])
      str.gsub(escaped) { [$&[1, 2].hex].pack('C') }.force_encoding(str.encoding)
    end

    @@to_s = Kernel.instance_method(:to_s)
    def inspect
      @@to_s.bind(self).call
    end

    private

    def initialize_pattern(opts = {})
      ret = {}
      ret[:ESCAPED] = escaped = (opts.delete(:ESCAPED) || PATTERN::ESCAPED)
      ret[:UNRESERVED] = unreserved = opts.delete(:UNRESERVED) || PATTERN::UNRESERVED
      ret[:RESERVED] = reserved = opts.delete(:RESERVED) || PATTERN::RESERVED
      ret[:DOMLABEL] = opts.delete(:DOMLABEL) || PATTERN::DOMLABEL
      ret[:TOPLABEL] = opts.delete(:TOPLABEL) || PATTERN::TOPLABEL
      ret[:HOSTNAME] = hostname = opts.delete(:HOSTNAME)


      ret[:URIC] = uric = "(?:[#{unreserved}#{reserved}]|#{escaped})"
      ret[:URIC_NO_SLASH] = uric_no_slash = "(?:[#{unreserved};?:@&=+$,]|#{escaped})"
      ret[:QUERY] = query = "#{uric}*"
      ret[:FRAGMENT] = fragment = "#{uric}*"

      unless hostname
        ret[:HOSTNAME] = hostname = "(?:[a-zA-Z0-9\\-.]|%\\h\\h)+"
      end

      ret[:IPV4ADDR] = ipv4addr = "\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}"
      hex4 = "[#{PATTERN::HEX}]{1,4}"
      lastpart = "(?:#{hex4}|#{ipv4addr})"
      hexseq1 = "(?:#{hex4}:)*#{hex4}"
      hexseq2 = "(?:#{hex4}:)*#{lastpart}"
      ret[:IPV6ADDR] = ipv6addr = "(?:#{hexseq2}|(?:#{hexseq1})?::(?:#{hexseq2})?)"


      ret[:IPV6REF] = ipv6ref = "\\[#{ipv6addr}\\]"

      ret[:HOST] = host = "(?:#{hostname}|#{ipv4addr}|#{ipv6ref})"
      port = '\d*'
      ret[:HOSTPORT] = hostport = "#{host}(?::#{port})?"

      ret[:USERINFO] = userinfo = "(?:[#{unreserved};:&=+$,]|#{escaped})*"

      pchar = "(?:[#{unreserved}:@&=+$,]|#{escaped})"
      param = "#{pchar}*"
      segment = "#{pchar}*(?:;#{param})*"
      ret[:PATH_SEGMENTS] = path_segments = "#{segment}(?:/#{segment})*"

      server = "(?:#{userinfo}@)?#{hostport}"
      ret[:REG_NAME] = reg_name = "(?:[#{unreserved}$,;:@&=+]|#{escaped})+"
      authority = "(?:#{server}|#{reg_name})"

      ret[:REL_SEGMENT] = rel_segment = "(?:[#{unreserved};@&=+$,]|#{escaped})+"

      ret[:SCHEME] = scheme = "[#{PATTERN::ALPHA}][\\-+.#{PATTERN::ALPHA}\\d]*"

      ret[:ABS_PATH] = abs_path = "/#{path_segments}"
      ret[:REL_PATH] = rel_path = "#{rel_segment}(?:#{abs_path})?"
      ret[:NET_PATH] = net_path = "//#{authority}(?:#{abs_path})?"

      ret[:HIER_PART] = hier_part = "(?:#{net_path}|#{abs_path})(?:\\?(?:#{query}))?"
      ret[:OPAQUE_PART] = opaque_part = "#{uric_no_slash}#{uric}*"

      ret[:ABS_URI] = abs_uri = "#{scheme}:(?:#{hier_part}|#{opaque_part})"
      ret[:REL_URI] = rel_uri = "(?:#{net_path}|#{abs_path}|#{rel_path})(?:\\?#{query})?"

      ret[:URI_REF] = "(?:#{abs_uri}|#{rel_uri})?(?:##{fragment})?"

      ret[:X_ABS_URI] = "
        (#{scheme}):                           (?# 1: scheme)
        (?:
           (#{opaque_part})                    (?# 2: opaque)
        |
           (?:(?:
             //(?:
                 (?:(?:(#{userinfo})@)?        (?# 3: userinfo)
                   (?:(#{host})(?::(\\d*))?))? (?# 4: host, 5: port)
               |
                 (#{reg_name})                 (?# 6: registry)
               )
             |
             (?!//))                           (?# XXX: '//' is the mark for hostport)
             (#{abs_path})?                    (?# 7: path)
           )(?:\\?(#{query}))?                 (?# 8: query)
        )
        (?:\\#(#{fragment}))?                  (?# 9: fragment)
      "

      ret[:X_REL_URI] = "
        (?:
          (?:
            //
            (?:
              (?:(#{userinfo})@)?       (?# 1: userinfo)
                (#{host})?(?::(\\d*))?  (?# 2: host, 3: port)
            |
              (#{reg_name})             (?# 4: registry)
            )
          )
        |
          (#{rel_segment})              (?# 5: rel_segment)
        )?
        (#{abs_path})?                  (?# 6: abs_path)
        (?:\\?(#{query}))?              (?# 7: query)
        (?:\\#(#{fragment}))?           (?# 8: fragment)
      "

      ret
    end

    def initialize_regexp(pattern)
      ret = {}

      ret[:ABS_URI] = Regexp.new('\A\s*' + pattern[:X_ABS_URI] + '\s*\z', Regexp::EXTENDED)
      ret[:REL_URI] = Regexp.new('\A\s*' + pattern[:X_REL_URI] + '\s*\z', Regexp::EXTENDED)

      ret[:URI_REF]     = Regexp.new(pattern[:URI_REF])
      ret[:ABS_URI_REF] = Regexp.new(pattern[:X_ABS_URI], Regexp::EXTENDED)
      ret[:REL_URI_REF] = Regexp.new(pattern[:X_REL_URI], Regexp::EXTENDED)

      ret[:ESCAPED] = Regexp.new(pattern[:ESCAPED])
      ret[:UNSAFE]  = Regexp.new("[^#{pattern[:UNRESERVED]}#{pattern[:RESERVED]}]")

      ret[:SCHEME]   = Regexp.new("\\A#{pattern[:SCHEME]}\\z")
      ret[:USERINFO] = Regexp.new("\\A#{pattern[:USERINFO]}\\z")
      ret[:HOST]     = Regexp.new("\\A#{pattern[:HOST]}\\z")
      ret[:PORT]     = Regexp.new("\\A#{pattern[:PORT]}\\z")
      ret[:OPAQUE]   = Regexp.new("\\A#{pattern[:OPAQUE_PART]}\\z")
      ret[:REGISTRY] = Regexp.new("\\A#{pattern[:REG_NAME]}\\z")
      ret[:ABS_PATH] = Regexp.new("\\A#{pattern[:ABS_PATH]}\\z")
      ret[:REL_PATH] = Regexp.new("\\A#{pattern[:REL_PATH]}\\z")
      ret[:QUERY]    = Regexp.new("\\A#{pattern[:QUERY]}\\z")
      ret[:FRAGMENT] = Regexp.new("\\A#{pattern[:FRAGMENT]}\\z")

      ret
    end

    def convert_to_uri(uri)
      if uri.is_a?(URI::Generic)
        uri
      elsif uri = String.try_convert(uri)
        parse(uri)
      else
        raise ArgumentError,
          "bad argument (expected URI object or URI string)"
      end
    end

  end # class Parser
end # module URI
