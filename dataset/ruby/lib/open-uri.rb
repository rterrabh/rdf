require 'uri'
require 'stringio'
require 'time'

module Kernel
  private
  alias open_uri_original_open open # :nodoc:
  class << self
    alias open_uri_original_open open # :nodoc:
  end

  def open(name, *rest, &block) # :doc:
    if name.respond_to?(:open)
      name.open(*rest, &block)
    elsif name.respond_to?(:to_str) &&
          %r{\A[A-Za-z][A-Za-z0-9+\-\.]*://} =~ name &&
          (uri = URI.parse(name)).respond_to?(:open)
      uri.open(*rest, &block)
    else
      open_uri_original_open(name, *rest, &block)
    end
  end
  module_function :open
end


module OpenURI
  Options = {
    :proxy => true,
    :proxy_http_basic_authentication => true,
    :progress_proc => true,
    :content_length_proc => true,
    :http_basic_authentication => true,
    :read_timeout => true,
    :open_timeout => true,
    :ssl_ca_cert => nil,
    :ssl_verify_mode => nil,
    :ftp_active_mode => false,
    :redirect => true,
  }

  def OpenURI.check_options(options) # :nodoc:
    options.each {|k, v|
      next unless Symbol === k
      unless Options.include? k
        raise ArgumentError, "unrecognized option: #{k}"
      end
    }
  end

  def OpenURI.scan_open_optional_arguments(*rest) # :nodoc:
    if !rest.empty? && (String === rest.first || Integer === rest.first)
      mode = rest.shift
      if !rest.empty? && Integer === rest.first
        perm = rest.shift
      end
    end
    return mode, perm, rest
  end

  def OpenURI.open_uri(name, *rest) # :nodoc:
    uri = URI::Generic === name ? name : URI.parse(name)
    mode, _, rest = OpenURI.scan_open_optional_arguments(*rest)
    options = rest.shift if !rest.empty? && Hash === rest.first
    raise ArgumentError.new("extra arguments") if !rest.empty?
    options ||= {}
    OpenURI.check_options(options)

    if /\Arb?(?:\Z|:([^:]+))/ =~ mode
      encoding, = $1,Encoding.find($1) if $1
      mode = nil
    end

    unless mode == nil ||
           mode == 'r' || mode == 'rb' ||
           mode == File::RDONLY
      raise ArgumentError.new("invalid access mode #{mode} (#{uri.class} resource is read only.)")
    end

    io = open_loop(uri, options)
    io.set_encoding(encoding) if encoding
    if block_given?
      begin
        yield io
      ensure
        if io.respond_to? :close!
          io.close! # Tempfile
        else
          io.close if !io.closed?
        end
      end
    else
      io
    end
  end

  def OpenURI.open_loop(uri, options) # :nodoc:
    proxy_opts = []
    proxy_opts << :proxy_http_basic_authentication if options.include? :proxy_http_basic_authentication
    proxy_opts << :proxy if options.include? :proxy
    proxy_opts.compact!
    if 1 < proxy_opts.length
      raise ArgumentError, "multiple proxy options specified"
    end
    case proxy_opts.first
    when :proxy_http_basic_authentication
      opt_proxy, proxy_user, proxy_pass = options.fetch(:proxy_http_basic_authentication)
      proxy_user = proxy_user.to_str
      proxy_pass = proxy_pass.to_str
      if opt_proxy == true
        raise ArgumentError.new("Invalid authenticated proxy option: #{options[:proxy_http_basic_authentication].inspect}")
      end
    when :proxy
      opt_proxy = options.fetch(:proxy)
      proxy_user = nil
      proxy_pass = nil
    when nil
      opt_proxy = true
      proxy_user = nil
      proxy_pass = nil
    end
    case opt_proxy
    when true
      find_proxy = lambda {|u| pxy = u.find_proxy; pxy ? [pxy, nil, nil] : nil}
    when nil, false
      find_proxy = lambda {|u| nil}
    when String
      opt_proxy = URI.parse(opt_proxy)
      find_proxy = lambda {|u| [opt_proxy, proxy_user, proxy_pass]}
    when URI::Generic
      find_proxy = lambda {|u| [opt_proxy, proxy_user, proxy_pass]}
    else
      raise ArgumentError.new("Invalid proxy option: #{opt_proxy}")
    end

    uri_set = {}
    buf = nil
    while true
      redirect = catch(:open_uri_redirect) {
        buf = Buffer.new
        uri.buffer_open(buf, find_proxy.call(uri), options)
        nil
      }
      if redirect
        if redirect.relative?
          redirect = uri + redirect
        end
        if !options.fetch(:redirect, true)
          raise HTTPRedirect.new(buf.io.status.join(' '), buf.io, redirect)
        end
        unless OpenURI.redirectable?(uri, redirect)
          raise "redirection forbidden: #{uri} -> #{redirect}"
        end
        if options.include? :http_basic_authentication
          options = options.dup
          options.delete :http_basic_authentication
        end
        uri = redirect
        raise "HTTP redirection loop: #{uri}" if uri_set.include? uri.to_s
        uri_set[uri.to_s] = true
      else
        break
      end
    end
    io = buf.io
    io.base_uri = uri
    io
  end

  def OpenURI.redirectable?(uri1, uri2) # :nodoc:
    uri1.scheme.downcase == uri2.scheme.downcase ||
    (/\A(?:http|ftp)\z/i =~ uri1.scheme && /\A(?:http|ftp)\z/i =~ uri2.scheme)
  end

  def OpenURI.open_http(buf, target, proxy, options) # :nodoc:
    if proxy
      proxy_uri, proxy_user, proxy_pass = proxy
      raise "Non-HTTP proxy URI: #{proxy_uri}" if proxy_uri.class != URI::HTTP
    end

    if target.userinfo
      raise ArgumentError, "userinfo not supported.  [RFC3986]"
    end

    header = {}
    options.each {|k, v| header[k] = v if String === k }

    require 'net/http'
    klass = Net::HTTP
    if URI::HTTP === target
      if proxy
        if proxy_user && proxy_pass
          klass = Net::HTTP::Proxy(proxy_uri.hostname, proxy_uri.port, proxy_user, proxy_pass)
        else
          klass = Net::HTTP::Proxy(proxy_uri.hostname, proxy_uri.port)
        end
      end
      target_host = target.hostname
      target_port = target.port
      request_uri = target.request_uri
    else
      target_host = proxy_uri.hostname
      target_port = proxy_uri.port
      request_uri = target.to_s
      if proxy_user && proxy_pass
        header["Proxy-Authorization"] = 'Basic ' + ["#{proxy_user}:#{proxy_pass}"].pack('m').delete("\r\n")
      end
    end

    http = proxy ? klass.new(target_host, target_port) : klass.new(target_host, target_port, nil)
    if target.class == URI::HTTPS
      require 'net/https'
      http.use_ssl = true
      http.verify_mode = options[:ssl_verify_mode] || OpenSSL::SSL::VERIFY_PEER
      store = OpenSSL::X509::Store.new
      if options[:ssl_ca_cert]
        Array(options[:ssl_ca_cert]).each do |cert|
          if File.directory? cert
            store.add_path cert
          else
            store.add_file cert
          end
        end
      else
        store.set_default_paths
      end
      http.cert_store = store
    end
    if options.include? :read_timeout
      http.read_timeout = options[:read_timeout]
    end
    if options.include? :open_timeout
      http.open_timeout = options[:open_timeout]
    end

    resp = nil
    http.start {
      req = Net::HTTP::Get.new(request_uri, header)
      if options.include? :http_basic_authentication
        user, pass = options[:http_basic_authentication]
        req.basic_auth user, pass
      end
      http.request(req) {|response|
        resp = response
        if options[:content_length_proc] && Net::HTTPSuccess === resp
          if resp.key?('Content-Length')
            options[:content_length_proc].call(resp['Content-Length'].to_i)
          else
            options[:content_length_proc].call(nil)
          end
        end
        resp.read_body {|str|
          buf << str
          if options[:progress_proc] && Net::HTTPSuccess === resp
            options[:progress_proc].call(buf.size)
          end
        }
      }
    }
    io = buf.io
    io.rewind
    io.status = [resp.code, resp.message]
    resp.each_name {|name| buf.io.meta_add_field2 name, resp.get_fields(name) }
    case resp
    when Net::HTTPSuccess
    when Net::HTTPMovedPermanently, # 301
         Net::HTTPFound, # 302
         Net::HTTPSeeOther, # 303
         Net::HTTPTemporaryRedirect # 307
      begin
        loc_uri = URI.parse(resp['location'])
      rescue URI::InvalidURIError
        raise OpenURI::HTTPError.new(io.status.join(' ') + ' (Invalid Location URI)', io)
      end
      throw :open_uri_redirect, loc_uri
    else
      raise OpenURI::HTTPError.new(io.status.join(' '), io)
    end
  end

  class HTTPError < StandardError
    def initialize(message, io)
      super(message)
      @io = io
    end
    attr_reader :io
  end

  class HTTPRedirect < HTTPError
    def initialize(message, io, uri)
      super(message, io)
      @uri = uri
    end
    attr_reader :uri
  end

  class Buffer # :nodoc: all
    def initialize
      @io = StringIO.new
      @size = 0
    end
    attr_reader :size

    StringMax = 10240
    def <<(str)
      @io << str
      @size += str.length
      if StringIO === @io && StringMax < @size
        require 'tempfile'
        io = Tempfile.new('open-uri')
        io.binmode
        Meta.init io, @io if Meta === @io
        io << @io.string
        @io = io
      end
    end

    def io
      Meta.init @io unless Meta === @io
      @io
    end
  end

  module Meta
    def Meta.init(obj, src=nil) # :nodoc:
      obj.extend Meta
      #nodyna <instance_eval-2169> <IEV COMPLEX (private access)>
      obj.instance_eval {
        @base_uri = nil
        @meta = {} # name to string.  legacy.
        @metas = {} # name to array of strings.
      }
      if src
        obj.status = src.status
        obj.base_uri = src.base_uri
        src.metas.each {|name, values|
          obj.meta_add_field2(name, values)
        }
      end
    end

    attr_accessor :status

    attr_accessor :base_uri

    attr_reader :meta

    attr_reader :metas

    def meta_setup_encoding # :nodoc:
      charset = self.charset
      enc = nil
      if charset
        begin
          enc = Encoding.find(charset)
        rescue ArgumentError
        end
      end
      enc = Encoding::ASCII_8BIT unless enc
      if self.respond_to? :force_encoding
        self.force_encoding(enc)
      elsif self.respond_to? :string
        self.string.force_encoding(enc)
      else # Tempfile
        self.set_encoding enc
      end
    end

    def meta_add_field2(name, values) # :nodoc:
      name = name.downcase
      @metas[name] = values
      @meta[name] = values.join(', ')
      meta_setup_encoding if name == 'content-type'
    end

    def meta_add_field(name, value) # :nodoc:
      meta_add_field2(name, [value])
    end

    def last_modified
      if vs = @metas['last-modified']
        v = vs.join(', ')
        Time.httpdate(v)
      else
        nil
      end
    end

    RE_LWS = /[\r\n\t ]+/n
    RE_TOKEN = %r{[^\x00- ()<>@,;:\\"/\[\]?={}\x7f]+}n
    RE_QUOTED_STRING = %r{"(?:[\r\n\t !#-\[\]-~\x80-\xff]|\\[\x00-\x7f])*"}n
    RE_PARAMETERS = %r{(?:;#{RE_LWS}?#{RE_TOKEN}#{RE_LWS}?=#{RE_LWS}?(?:#{RE_TOKEN}|#{RE_QUOTED_STRING})#{RE_LWS}?)*}n

    def content_type_parse # :nodoc:
      vs = @metas['content-type']
      if vs && %r{\A#{RE_LWS}?(#{RE_TOKEN})#{RE_LWS}?/(#{RE_TOKEN})#{RE_LWS}?(#{RE_PARAMETERS})(?:;#{RE_LWS}?)?\z}no =~ vs.join(', ')
        type = $1.downcase
        subtype = $2.downcase
        parameters = []
        $3.scan(/;#{RE_LWS}?(#{RE_TOKEN})#{RE_LWS}?=#{RE_LWS}?(?:(#{RE_TOKEN})|(#{RE_QUOTED_STRING}))/no) {|att, val, qval|
          if qval
            val = qval[1...-1].gsub(/[\r\n\t !#-\[\]-~\x80-\xff]+|(\\[\x00-\x7f])/n) { $1 ? $1[1,1] : $& }
          end
          parameters << [att.downcase, val]
        }
        ["#{type}/#{subtype}", *parameters]
      else
        nil
      end
    end

    def content_type
      type, *_ = content_type_parse
      type || 'application/octet-stream'
    end

    def charset
      type, *parameters = content_type_parse
      if pair = parameters.assoc('charset')
        pair.last.downcase
      elsif block_given?
        yield
      elsif type && %r{\Atext/} =~ type &&
            @base_uri && /\Ahttp\z/i =~ @base_uri.scheme
        "iso-8859-1" # RFC2616 3.7.1
      else
        nil
      end
    end

    def content_encoding
      vs = @metas['content-encoding']
      if vs && %r{\A#{RE_LWS}?#{RE_TOKEN}#{RE_LWS}?(?:,#{RE_LWS}?#{RE_TOKEN}#{RE_LWS}?)*}o =~ (v = vs.join(', '))
        v.scan(RE_TOKEN).map {|content_coding| content_coding.downcase}
      else
        []
      end
    end
  end

  module OpenRead
    def open(*rest, &block)
      OpenURI.open_uri(self, *rest, &block)
    end

    def read(options={})
      self.open(options) {|f|
        str = f.read
        Meta.init str, f
        str
      }
    end
  end
end

module URI
  class HTTP
    def buffer_open(buf, proxy, options) # :nodoc:
      OpenURI.open_http(buf, self, proxy, options)
    end

    include OpenURI::OpenRead
  end

  class FTP
    def buffer_open(buf, proxy, options) # :nodoc:
      if proxy
        OpenURI.open_http(buf, self, proxy, options)
        return
      end
      require 'net/ftp'

      path = self.path
      path = path.sub(%r{\A/}, '%2F') # re-encode the beginning slash because uri library decodes it.
      directories = path.split(%r{/}, -1)
      directories.each {|d|
        d.gsub!(/%([0-9A-Fa-f][0-9A-Fa-f])/) { [$1].pack("H2") }
      }
      unless filename = directories.pop
        raise ArgumentError, "no filename: #{self.inspect}"
      end
      directories.each {|d|
        if /[\r\n]/ =~ d
          raise ArgumentError, "invalid directory: #{d.inspect}"
        end
      }
      if /[\r\n]/ =~ filename
        raise ArgumentError, "invalid filename: #{filename.inspect}"
      end
      typecode = self.typecode
      if typecode && /\A[aid]\z/ !~ typecode
        raise ArgumentError, "invalid typecode: #{typecode.inspect}"
      end

      ftp = Net::FTP.new
      ftp.connect(self.hostname, self.port)
      ftp.passive = true if !options[:ftp_active_mode]
      user = 'anonymous'
      passwd = nil
      user, passwd = self.userinfo.split(/:/) if self.userinfo
      ftp.login(user, passwd)
      directories.each {|cwd|
        ftp.voidcmd("CWD #{cwd}")
      }
      if typecode
        ftp.voidcmd("TYPE #{typecode.upcase}")
      end
      if options[:content_length_proc]
        options[:content_length_proc].call(ftp.size(filename))
      end
      ftp.retrbinary("RETR #{filename}", 4096) { |str|
        buf << str
        options[:progress_proc].call(buf.size) if options[:progress_proc]
      }
      ftp.close
      buf.io.rewind
    end

    include OpenURI::OpenRead
  end
end
