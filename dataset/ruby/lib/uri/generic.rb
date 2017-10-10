
require 'uri/common'

module URI

  class Generic
    include URI

    DEFAULT_PORT = nil

    def self.default_port
      self::DEFAULT_PORT
    end

    def default_port
      self.class.default_port
    end

    COMPONENT = [
      :scheme,
      :userinfo, :host, :port, :registry,
      :path, :opaque,
      :query,
      :fragment
    ].freeze

    def self.component
      self::COMPONENT
    end

    USE_REGISTRY = false # :nodoc:

    def self.use_registry # :nodoc:
      self::USE_REGISTRY
    end

    def self.build2(args)
      begin
        return self.build(args)
      rescue InvalidComponentError
        if args.kind_of?(Array)
          return self.build(args.collect{|x|
            if x.is_a?(String)
              DEFAULT_PARSER.escape(x)
            else
              x
            end
          })
        elsif args.kind_of?(Hash)
          tmp = {}
          args.each do |key, value|
            tmp[key] = if value
                DEFAULT_PARSER.escape(value)
              else
                value
              end
          end
          return self.build(tmp)
        end
      end
    end

    def self.build(args)
      if args.kind_of?(Array) &&
          args.size == ::URI::Generic::COMPONENT.size
        tmp = args.dup
      elsif args.kind_of?(Hash)
        tmp = ::URI::Generic::COMPONENT.collect do |c|
          if args.include?(c)
            args[c]
          else
            nil
          end
        end
      else
        component = self.class.component rescue ::URI::Generic::COMPONENT
        raise ArgumentError,
        "expected Array of or Hash of components of #{self.class} (#{component.join(', ')})"
      end

      tmp << nil
      tmp << true
      return self.new(*tmp)
    end
    def initialize(scheme,
                   userinfo, host, port, registry,
                   path, opaque,
                   query,
                   fragment,
                   parser = DEFAULT_PARSER,
                   arg_check = false)
      @scheme = nil
      @user = nil
      @password = nil
      @host = nil
      @port = nil
      @path = nil
      @query = nil
      @opaque = nil
      @fragment = nil
      @parser = parser == DEFAULT_PARSER ? nil : parser

      if arg_check
        self.scheme = scheme
        self.userinfo = userinfo
        self.hostname = host
        self.port = port
        self.path = path
        self.query = query
        self.opaque = opaque
        self.fragment = fragment
      else
        self.set_scheme(scheme)
        self.set_userinfo(userinfo)
        self.set_host(host)
        self.set_port(port)
        self.set_path(path)
        self.query = query
        self.set_opaque(opaque)
        self.fragment=(fragment)
      end
      if registry
        raise InvalidURIError,
          "the scheme #{@scheme} does not accept registry part: #{registry} (or bad hostname?)"
      end

      @scheme.freeze if @scheme
      self.set_path('') if !@path && !@opaque # (see RFC2396 Section 5.2)
      self.set_port(self.default_port) if self.default_port && !@port
    end

    attr_reader :scheme

    attr_reader :host

    attr_reader :port

    def registry # :nodoc:
      nil
    end

    attr_reader :path

    attr_reader :query

    attr_reader :opaque

    attr_reader :fragment

    def parser
      if !defined?(@parser) || !@parser
        DEFAULT_PARSER
      else
        @parser || DEFAULT_PARSER
      end
    end

    def replace!(oth)
      if self.class != oth.class
        raise ArgumentError, "expected #{self.class} object"
      end

      component.each do |c|
        self.__send__("#{c}=", oth.__send__(c))
      end
    end
    private :replace!

    def component
      self.class.component
    end

    def check_scheme(v)
      if v && parser.regexp[:SCHEME] !~ v
        raise InvalidComponentError,
          "bad component(expected scheme component): #{v}"
      end

      return true
    end
    private :check_scheme

    def set_scheme(v)
      @scheme = v ? v.downcase : v
    end
    protected :set_scheme

    def scheme=(v)
      check_scheme(v)
      set_scheme(v)
      v
    end

    def check_userinfo(user, password = nil)
      if !password
        user, password = split_userinfo(user)
      end
      check_user(user)
      check_password(password, user)

      return true
    end
    private :check_userinfo

    def check_user(v)
      if @opaque
        raise InvalidURIError,
          "can not set user with opaque"
      end

      return v unless v

      if parser.regexp[:USERINFO] !~ v
        raise InvalidComponentError,
          "bad component(expected userinfo component or user component): #{v}"
      end

      return true
    end
    private :check_user

    def check_password(v, user = @user)
      if @opaque
        raise InvalidURIError,
          "can not set password with opaque"
      end
      return v unless v

      if !user
        raise InvalidURIError,
          "password component depends user component"
      end

      if parser.regexp[:USERINFO] !~ v
        raise InvalidComponentError,
          "bad component(expected user component): #{v}"
      end

      return true
    end
    private :check_password

    def userinfo=(userinfo)
      if userinfo.nil?
        return nil
      end
      check_userinfo(*userinfo)
      set_userinfo(*userinfo)
    end

    def user=(user)
      check_user(user)
      set_user(user)
    end

    def password=(password)
      check_password(password)
      set_password(password)
    end

    def set_userinfo(user, password = nil)
      unless password
        user, password = split_userinfo(user)
      end
      @user     = user
      @password = password if password

      [@user, @password]
    end
    protected :set_userinfo

    def set_user(v)
      set_userinfo(v, @password)
      v
    end
    protected :set_user

    def set_password(v)
      @password = v
    end
    protected :set_password

    def split_userinfo(ui)
      return nil, nil unless ui
      user, password = ui.split(':'.freeze, 2)

      return user, password
    end
    private :split_userinfo

    def escape_userpass(v)
      parser.escape(v, /[@:\/]/o) # RFC 1738 section 3.1 #/
    end
    private :escape_userpass

    def userinfo
      if @user.nil?
        nil
      elsif @password.nil?
        @user
      else
        @user + ':' + @password
      end
    end

    def user
      @user
    end

    def password
      @password
    end

    def check_host(v)
      return v unless v

      if @opaque
        raise InvalidURIError,
          "can not set host with registry or opaque"
      elsif parser.regexp[:HOST] !~ v
        raise InvalidComponentError,
          "bad component(expected host component): #{v}"
      end

      return true
    end
    private :check_host

    def set_host(v)
      @host = v
    end
    protected :set_host

    def host=(v)
      check_host(v)
      set_host(v)
      v
    end

    def hostname
      v = self.host
      /\A\[(.*)\]\z/ =~ v ? $1 : v
    end

    def hostname=(v)
      v = "[#{v}]" if /\A\[.*\]\z/ !~ v && /:/ =~ v
      self.host = v
    end

    def check_port(v)
      return v unless v

      if @opaque
        raise InvalidURIError,
          "can not set port with registry or opaque"
      elsif !v.kind_of?(Fixnum) && parser.regexp[:PORT] !~ v
        raise InvalidComponentError,
          "bad component(expected port component): #{v.inspect}"
      end

      return true
    end
    private :check_port

    def set_port(v)
      v = v.empty? ? nil : v.to_i unless !v || v.kind_of?(Fixnum)
      @port = v
    end
    protected :set_port

    def port=(v)
      check_port(v)
      set_port(v)
      port
    end

    def check_registry(v) # :nodoc:
      raise InvalidURIError, "can not set registry"
    end
    private :check_registry

    def set_registry(v) #:nodoc:
      raise InvalidURIError, "can not set registry"
    end
    protected :set_registry

    def registry=(v)
      raise InvalidURIError, "can not set registry"
    end

    def check_path(v)
      if v && @opaque
        raise InvalidURIError,
          "path conflicts with opaque"
      end

      if @scheme && @scheme != "ftp".freeze
        if v && v != ''.freeze && parser.regexp[:ABS_PATH] !~ v
          raise InvalidComponentError,
            "bad component(expected absolute path component): #{v}"
        end
      else
        if v && v != ''.freeze && parser.regexp[:ABS_PATH] !~ v &&
           parser.regexp[:REL_PATH] !~ v
          raise InvalidComponentError,
            "bad component(expected relative path component): #{v}"
        end
      end

      return true
    end
    private :check_path

    def set_path(v)
      @path = v
    end
    protected :set_path

    def path=(v)
      check_path(v)
      set_path(v)
      v
    end

    def query=(v)
      return @query = nil unless v
      raise InvalidURIError, "query conflicts with opaque" if @opaque

      x = v.to_str
      v = x.dup if x.equal? v
      v.encode!(Encoding::UTF_8) rescue nil
      v.delete!("\t\r\n".freeze)
      v.force_encoding(Encoding::ASCII_8BIT)
      v.gsub!(/(?!%\h\h|[!$-&(-;=?-_a-~])./n.freeze){'%%%02X'.freeze % $&.ord}
      v.force_encoding(Encoding::US_ASCII)
      @query = v
    end

    def check_opaque(v)
      return v unless v

      if @host || @port || @user || @path  # userinfo = @user + ':' + @password
        raise InvalidURIError,
          "can not set opaque with host, port, userinfo or path"
      elsif v && parser.regexp[:OPAQUE] !~ v
        raise InvalidComponentError,
          "bad component(expected opaque component): #{v}"
      end

      return true
    end
    private :check_opaque

    def set_opaque(v)
      @opaque = v
    end
    protected :set_opaque

    def opaque=(v)
      check_opaque(v)
      set_opaque(v)
      v
    end

    def fragment=(v)
      return @fragment = nil unless v

      x = v.to_str
      v = x.dup if x.equal? v
      v.encode!(Encoding::UTF_8) rescue nil
      v.delete!("\t\r\n".freeze)
      v.force_encoding(Encoding::ASCII_8BIT)
      v.gsub!(/(?!%\h\h|[!-~])./n){'%%%02X'.freeze % $&.ord}
      v.force_encoding(Encoding::US_ASCII)
      @fragment = v
    end

    def hierarchical?
      if @path
        true
      else
        false
      end
    end

    def absolute?
      if @scheme
        true
      else
        false
      end
    end
    alias absolute absolute?

    def relative?
      !absolute?
    end

    def split_path(path)
      path.split(%r{/+}, -1)
    end
    private :split_path

    def merge_path(base, rel)

      base_path = split_path(base)
      rel_path  = split_path(rel)

      base_path << '' if base_path.last == '..'
      while i = base_path.index('..')
        base_path.slice!(i - 1, 2)
      end

      if (first = rel_path.first) and first.empty?
        base_path.clear
        rel_path.shift
      end

      rel_path.push('') if rel_path.last == '.' || rel_path.last == '..'
      rel_path.delete('.')

      tmp = []
      rel_path.each do |x|
        if x == '..' &&
            !(tmp.empty? || tmp.last == '..')
          tmp.pop
        else
          tmp << x
        end
      end

      add_trailer_slash = !tmp.empty?
      if base_path.empty?
        base_path = [''] # keep '/' for root directory
      elsif add_trailer_slash
        base_path.pop
      end
      while x = tmp.shift
        if x == '..'
          base_path.pop if base_path.size > 1
        else
          base_path << x
          tmp.each {|t| base_path << t}
          add_trailer_slash = false
          break
        end
      end
      base_path.push('') if add_trailer_slash

      return base_path.join('/')
    end
    private :merge_path

    def merge!(oth)
      t = merge(oth)
      if self == t
        nil
      else
        replace!(t)
        self
      end
    end

    def merge(oth)
      begin
        base, rel = merge0(oth)
      rescue
        raise $!.class, $!.message
      end

      if base == rel
        return base
      end

      authority = rel.userinfo || rel.host || rel.port

      if (rel.path.nil? || rel.path.empty?) && !authority && !rel.query
        base.fragment=(rel.fragment) if rel.fragment
        return base
      end

      base.query = nil
      base.fragment=(nil)

      if !authority
        base.set_path(merge_path(base.path, rel.path)) if base.path && rel.path
      else
        base.set_path(rel.path) if rel.path
      end

      base.set_userinfo(rel.userinfo) if rel.userinfo
      base.set_host(rel.host)         if rel.host
      base.set_port(rel.port)         if rel.port
      base.query = rel.query       if rel.query
      base.fragment=(rel.fragment) if rel.fragment

      return base
    end # merge
    alias + merge

    def merge0(oth)
      #nodyna <send-2236> <SD EASY (private methods)>
      oth = parser.send(:convert_to_uri, oth)

      if self.relative? && oth.relative?
        raise BadURIError,
          "both URI are relative"
      end

      if self.absolute? && oth.absolute?
        return oth, oth
      end

      if self.absolute?
        return self.dup, oth
      else
        return oth, oth
      end
    end
    private :merge0

    def route_from_path(src, dst)
      case dst
      when src
        return ''
      when %r{(?:\A|/)\.\.?(?:/|\z)}
        return dst.dup
      end

      src_path = src.scan(%r{(?:\A|[^/]+)/})
      dst_path = dst.scan(%r{(?:\A|[^/]+)/?})

      while !dst_path.empty? && dst_path.first == src_path.first
        src_path.shift
        dst_path.shift
      end

      tmp = dst_path.join

      if src_path.empty?
        if tmp.empty?
          return './'
        elsif dst_path.first.include?(':') # (see RFC2396 Section 5)
          return './' + tmp
        else
          return tmp
        end
      end

      return '../' * src_path.size + tmp
    end
    private :route_from_path

    def route_from0(oth)
      #nodyna <send-2237> <SD EASY (private methods)>
      oth = parser.send(:convert_to_uri, oth)
      if self.relative?
        raise BadURIError,
          "relative URI: #{self}"
      end
      if oth.relative?
        raise BadURIError,
          "relative URI: #{oth}"
      end

      if self.scheme != oth.scheme
        return self, self.dup
      end
      rel = URI::Generic.new(nil, # it is relative URI
                             self.userinfo, self.host, self.port,
                             nil, self.path, self.opaque,
                             self.query, self.fragment, parser)

      if rel.userinfo != oth.userinfo ||
          rel.host.to_s.downcase != oth.host.to_s.downcase ||
          rel.port != oth.port

        if self.userinfo.nil? && self.host.nil?
          return self, self.dup
        end

        rel.set_port(nil) if rel.port == oth.default_port
        return rel, rel
      end
      rel.set_userinfo(nil)
      rel.set_host(nil)
      rel.set_port(nil)

      if rel.path && rel.path == oth.path
        rel.set_path('')
        rel.query = nil if rel.query == oth.query
        return rel, rel
      elsif rel.opaque && rel.opaque == oth.opaque
        rel.set_opaque('')
        rel.query = nil if rel.query == oth.query
        return rel, rel
      end

      return oth, rel
    end
    private :route_from0

    def route_from(oth)
      begin
        oth, rel = route_from0(oth)
      rescue
        raise $!.class, $!.message
      end
      if oth == rel
        return rel
      end

      rel.set_path(route_from_path(oth.path, self.path))
      if rel.path == './' && self.query
        rel.set_path('')
      end

      return rel
    end

    alias - route_from

    def route_to(oth)
      #nodyna <send-2238> <SD EASY (private methods)>
      parser.send(:convert_to_uri, oth).route_from(self)
    end

    def normalize
      uri = dup
      uri.normalize!
      uri
    end

    def normalize!
      if path && path.empty?
        set_path('/')
      end
      if scheme && scheme != scheme.downcase
        set_scheme(self.scheme.downcase)
      end
      if host && host != host.downcase
        set_host(self.host.downcase)
      end
    end

    def to_s
      str = ''
      if @scheme
        str << @scheme
        str << ':'.freeze
      end

      if @opaque
        str << @opaque
      else
        if @host
          str << '//'.freeze
        end
        if self.userinfo
          str << self.userinfo
          str << '@'.freeze
        end
        if @host
          str << @host
        end
        if @port && @port != self.default_port
          str << ':'.freeze
          str << @port.to_s
        end
        str << @path
        if @query
          str << '?'.freeze
          str << @query
        end
      end
      if @fragment
        str << '#'.freeze
        str << @fragment
      end
      str
    end

    def ==(oth)
      if self.class == oth.class
        self.normalize.component_ary == oth.normalize.component_ary
      else
        false
      end
    end

    def hash
      self.component_ary.hash
    end

    def eql?(oth)
      self.class == oth.class &&
      parser == oth.parser &&
      self.component_ary.eql?(oth.component_ary)
    end

=begin

--- URI::Generic#===(oth)

=end

=begin
=end


    def component_ary
      component.collect do |x|
        #nodyna <send-2239> <SD COMPLEX (change-prone variables)>
        self.send(x)
      end
    end
    protected :component_ary

    def select(*components)
      components.collect do |c|
        if component.include?(c)
          #nodyna <send-2240> <SD COMPLEX (change-prone variables)>
          self.send(c)
        else
          raise ArgumentError,
            "expected of components of #{self.class} (#{self.class.component.join(', ')})"
        end
      end
    end

    def inspect
      "#<#{self.class} #{self}>"
    end

    def coerce(oth)
      case oth
      when String
        oth = parser.parse(oth)
      else
        super
      end

      return oth, self
    end

    def find_proxy
      raise BadURIError, "relative URI: #{self}" if self.relative?
      name = self.scheme.downcase + '_proxy'
      proxy_uri = nil
      if name == 'http_proxy' && ENV.include?('REQUEST_METHOD') # CGI?
        pairs = ENV.reject {|k, v| /\Ahttp_proxy\z/i !~ k }
        case pairs.length
        when 0 # no proxy setting anyway.
          proxy_uri = nil
        when 1
          k, _ = pairs.shift
          if k == 'http_proxy' && ENV[k.upcase] == nil
            proxy_uri = ENV[name]
          else
            proxy_uri = nil
          end
        else # http_proxy is safe to use because ENV is case sensitive.
          proxy_uri = ENV.to_hash[name]
        end
        if !proxy_uri
          proxy_uri = ENV["CGI_#{name.upcase}"]
        end
      elsif name == 'http_proxy'
        unless proxy_uri = ENV[name]
          if proxy_uri = ENV[name.upcase]
            warn 'The environment variable HTTP_PROXY is discouraged.  Use http_proxy.'
          end
        end
      else
        proxy_uri = ENV[name] || ENV[name.upcase]
      end

      if proxy_uri.nil? || proxy_uri.empty?
        return nil
      end

      if self.hostname
        require 'socket'
        begin
          addr = IPSocket.getaddress(self.hostname)
          return nil if /\A127\.|\A::1\z/ =~ addr
        rescue SocketError
        end
      end

      name = 'no_proxy'
      if no_proxy = ENV[name] || ENV[name.upcase]
        no_proxy.scan(/([^:,]*)(?::(\d+))?/) {|host, port|
          if /(\A|\.)#{Regexp.quote host}\z/i =~ self.host &&
            (!port || self.port == port.to_i)
            return nil
          end
        }
      end
      URI.parse(proxy_uri)
    end
  end
end
