
require 'net/protocol'
require 'uri'

module Net   #:nodoc:
  autoload :OpenSSL, 'openssl'

  class HTTPBadResponse < StandardError; end
  class HTTPHeaderSyntaxError < StandardError; end

  class HTTP < Protocol

    Revision = %q$Revision$.split[1]
    HTTPVersion = '1.1'
    begin
      require 'zlib'
      require 'stringio'  #for our purposes (unpacking gzip) lump these together
      HAVE_ZLIB=true
    rescue LoadError
      HAVE_ZLIB=false
    end

    def HTTP.version_1_2
      true
    end

    def HTTP.version_1_2?
      true
    end

    def HTTP.version_1_1?  #:nodoc:
      false
    end

    class << HTTP
      alias is_version_1_1? version_1_1?   #:nodoc:
      alias is_version_1_2? version_1_2?   #:nodoc:
    end


    def HTTP.get_print(uri_or_host, path = nil, port = nil)
      get_response(uri_or_host, path, port) {|res|
        res.read_body do |chunk|
          $stdout.print chunk
        end
      }
      nil
    end

    def HTTP.get(uri_or_host, path = nil, port = nil)
      get_response(uri_or_host, path, port).body
    end

    def HTTP.get_response(uri_or_host, path = nil, port = nil, &block)
      if path
        host = uri_or_host
        new(host, port || HTTP.default_port).start {|http|
          return http.request_get(path, &block)
        }
      else
        uri = uri_or_host
        start(uri.hostname, uri.port,
              :use_ssl => uri.scheme == 'https') {|http|
          return http.request_get(uri, &block)
        }
      end
    end

    def HTTP.post_form(url, params)
      req = Post.new(url)
      req.form_data = params
      req.basic_auth url.user, url.password if url.user
      start(url.hostname, url.port,
            :use_ssl => url.scheme == 'https' ) {|http|
        http.request(req)
      }
    end


    def HTTP.default_port
      http_default_port()
    end

    def HTTP.http_default_port
      80
    end

    def HTTP.https_default_port
      443
    end

    def HTTP.socket_type   #:nodoc: obsolete
      BufferedIO
    end

    def HTTP.start(address, *arg, &block) # :yield: +http+
      arg.pop if opt = Hash.try_convert(arg[-1])
      port, p_addr, p_port, p_user, p_pass = *arg
      port = https_default_port if !port && opt && opt[:use_ssl]
      http = new(address, port, p_addr, p_port, p_user, p_pass)

      if opt
        if opt[:use_ssl]
          opt = {verify_mode: OpenSSL::SSL::VERIFY_PEER}.update(opt)
        end
        http.methods.grep(/\A(\w+)=\z/) do |meth|
          key = $1.to_sym
          opt.key?(key) or next
          http.__send__(meth, opt[key])
        end
      end

      http.start(&block)
    end

    class << HTTP
      alias newobj new # :nodoc:
    end

    def HTTP.new(address, port = nil, p_addr = :ENV, p_port = nil, p_user = nil, p_pass = nil)
      http = super address, port

      if proxy_class? then # from Net::HTTP::Proxy()
        http.proxy_from_env = @proxy_from_env
        http.proxy_address  = @proxy_address
        http.proxy_port     = @proxy_port
        http.proxy_user     = @proxy_user
        http.proxy_pass     = @proxy_pass
      elsif p_addr == :ENV then
        http.proxy_from_env = true
      else
        http.proxy_address = p_addr
        http.proxy_port    = p_port || default_port
        http.proxy_user    = p_user
        http.proxy_pass    = p_pass
      end

      http
    end

    def initialize(address, port = nil)
      @address = address
      @port    = (port || HTTP.default_port)
      @local_host = nil
      @local_port = nil
      @curr_http_version = HTTPVersion
      @keep_alive_timeout = 2
      @last_communicated = nil
      @close_on_empty_response = false
      @socket  = nil
      @started = false
      @open_timeout = nil
      @read_timeout = 60
      @continue_timeout = nil
      @debug_output = nil

      @proxy_from_env = false
      @proxy_uri      = nil
      @proxy_address  = nil
      @proxy_port     = nil
      @proxy_user     = nil
      @proxy_pass     = nil

      @use_ssl = false
      @ssl_context = nil
      @ssl_session = nil
      @enable_post_connection_check = true
      @sspi_enabled = false
      SSL_IVNAMES.each do |ivname|
        #nodyna <instance_variable_set-2160> <not yet classified>
        instance_variable_set ivname, nil
      end
    end

    def inspect
      "#<#{self.class} #{@address}:#{@port} open=#{started?}>"
    end

    def set_debug_output(output)
      warn 'Net::HTTP#set_debug_output called after HTTP started' if started?
      @debug_output = output
    end

    attr_reader :address

    attr_reader :port

    attr_accessor :local_host

    attr_accessor :local_port

    attr_writer :proxy_from_env
    attr_writer :proxy_address
    attr_writer :proxy_port
    attr_writer :proxy_user
    attr_writer :proxy_pass

    attr_accessor :open_timeout

    attr_reader :read_timeout

    def read_timeout=(sec)
      @socket.read_timeout = sec if @socket
      @read_timeout = sec
    end

    attr_reader :continue_timeout

    def continue_timeout=(sec)
      @socket.continue_timeout = sec if @socket
      @continue_timeout = sec
    end

    attr_accessor :keep_alive_timeout

    def started?
      @started
    end

    alias active? started?   #:nodoc: obsolete

    attr_accessor :close_on_empty_response

    def use_ssl?
      @use_ssl
    end

    def use_ssl=(flag)
      flag = flag ? true : false
      if started? and @use_ssl != flag
        raise IOError, "use_ssl value changed, but session already started"
      end
      @use_ssl = flag
    end

    SSL_IVNAMES = [
      :@ca_file,
      :@ca_path,
      :@cert,
      :@cert_store,
      :@ciphers,
      :@key,
      :@ssl_timeout,
      :@ssl_version,
      :@verify_callback,
      :@verify_depth,
      :@verify_mode,
    ]
    SSL_ATTRIBUTES = [
      :ca_file,
      :ca_path,
      :cert,
      :cert_store,
      :ciphers,
      :key,
      :ssl_timeout,
      :ssl_version,
      :verify_callback,
      :verify_depth,
      :verify_mode,
    ]

    attr_accessor :ca_file

    attr_accessor :ca_path

    attr_accessor :cert

    attr_accessor :cert_store

    attr_accessor :ciphers

    attr_accessor :key

    attr_accessor :ssl_timeout

    attr_accessor :ssl_version

    attr_accessor :verify_callback

    attr_accessor :verify_depth

    attr_accessor :verify_mode

    def peer_cert
      if not use_ssl? or not @socket
        return nil
      end
      @socket.io.peer_cert
    end

    def start  # :yield: http
      raise IOError, 'HTTP session already opened' if @started
      if block_given?
        begin
          do_start
          return yield(self)
        ensure
          do_finish
        end
      end
      do_start
      self
    end

    def do_start
      connect
      @started = true
    end
    private :do_start

    def connect
      if proxy? then
        conn_address = proxy_address
        conn_port    = proxy_port
      else
        conn_address = address
        conn_port    = port
      end

      D "opening connection to #{conn_address}:#{conn_port}..."
      s = Timeout.timeout(@open_timeout, Net::OpenTimeout) {
        TCPSocket.open(conn_address, conn_port, @local_host, @local_port)
      }
      s.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)
      D "opened"
      if use_ssl?
        ssl_parameters = Hash.new
        iv_list = instance_variables
        SSL_IVNAMES.each_with_index do |ivname, i|
          if iv_list.include?(ivname) and
            #nodyna <instance_variable_get-2161> <not yet classified>
            value = instance_variable_get(ivname)
            ssl_parameters[SSL_ATTRIBUTES[i]] = value if value
          end
        end
        @ssl_context = OpenSSL::SSL::SSLContext.new
        @ssl_context.set_params(ssl_parameters)
        D "starting SSL for #{conn_address}:#{conn_port}..."
        s = OpenSSL::SSL::SSLSocket.new(s, @ssl_context)
        s.sync_close = true
        D "SSL established"
      end
      @socket = BufferedIO.new(s)
      @socket.read_timeout = @read_timeout
      @socket.continue_timeout = @continue_timeout
      @socket.debug_output = @debug_output
      if use_ssl?
        begin
          if proxy?
            buf = "CONNECT #{@address}:#{@port} HTTP/#{HTTPVersion}\r\n"
            buf << "Host: #{@address}:#{@port}\r\n"
            if proxy_user
              credential = ["#{proxy_user}:#{proxy_pass}"].pack('m')
              credential.delete!("\r\n")
              buf << "Proxy-Authorization: Basic #{credential}\r\n"
            end
            buf << "\r\n"
            @socket.write(buf)
            HTTPResponse.read_new(@socket).value
          end
          if @ssl_session and
             Process.clock_gettime(Process::CLOCK_REALTIME) < @ssl_session.time.to_f + @ssl_session.timeout
            s.session = @ssl_session if @ssl_session
          end
          s.hostname = @address if s.respond_to? :hostname=
          Timeout.timeout(@open_timeout, Net::OpenTimeout) { s.connect }
          if @ssl_context.verify_mode != OpenSSL::SSL::VERIFY_NONE
            s.post_connection_check(@address)
          end
          @ssl_session = s.session
        rescue => exception
          D "Conn close because of connect error #{exception}"
          @socket.close if @socket and not @socket.closed?
          raise exception
        end
      end
      on_connect
    end
    private :connect

    def on_connect
    end
    private :on_connect

    def finish
      raise IOError, 'HTTP session not yet started' unless started?
      do_finish
    end

    def do_finish
      @started = false
      @socket.close if @socket and not @socket.closed?
      @socket = nil
    end
    private :do_finish


    public

    @is_proxy_class = false
    @proxy_from_env = false
    @proxy_addr = nil
    @proxy_port = nil
    @proxy_user = nil
    @proxy_pass = nil

    def HTTP.Proxy(p_addr = :ENV, p_port = nil, p_user = nil, p_pass = nil)
      return self unless p_addr

      Class.new(self) {
        @is_proxy_class = true

        if p_addr == :ENV then
          @proxy_from_env = true
          @proxy_address = nil
          @proxy_port    = nil
        else
          @proxy_from_env = false
          @proxy_address = p_addr
          @proxy_port    = p_port || default_port
        end

        @proxy_user = p_user
        @proxy_pass = p_pass
      }
    end

    class << HTTP
      def proxy_class?
        defined?(@is_proxy_class) ? @is_proxy_class : false
      end

      attr_reader :proxy_address

      attr_reader :proxy_port

      attr_reader :proxy_user

      attr_reader :proxy_pass
    end

    def proxy?
      !!if @proxy_from_env then
        proxy_uri
      else
        @proxy_address
      end
    end

    def proxy_from_env?
      @proxy_from_env
    end

    def proxy_uri # :nodoc:
      @proxy_uri ||= URI::HTTP.new(
        "http".freeze, nil, address, port, nil, nil, nil, nil, nil
      ).find_proxy
    end

    def proxy_address
      if @proxy_from_env then
        proxy_uri && proxy_uri.hostname
      else
        @proxy_address
      end
    end

    def proxy_port
      if @proxy_from_env then
        proxy_uri && proxy_uri.port
      else
        @proxy_port
      end
    end

    def proxy_user
      @proxy_user
    end

    def proxy_pass
      @proxy_pass
    end

    alias proxyaddr proxy_address   #:nodoc: obsolete
    alias proxyport proxy_port      #:nodoc: obsolete

    private


    def conn_address # :nodoc:
      address()
    end

    def conn_port # :nodoc:
      port()
    end

    def edit_path(path)
      if proxy? and not use_ssl? then
        "http://#{addr_port}#{path}"
      else
        path
      end
    end


    public

    def get(path, initheader = nil, dest = nil, &block) # :yield: +body_segment+
      res = nil
      request(Get.new(path, initheader)) {|r|
        r.read_body dest, &block
        res = r
      }
      res
    end

    def head(path, initheader = nil)
      request(Head.new(path, initheader))
    end

    def post(path, data, initheader = nil, dest = nil, &block) # :yield: +body_segment+
      send_entity(path, data, initheader, dest, Post, &block)
    end

    def patch(path, data, initheader = nil, dest = nil, &block) # :yield: +body_segment+
      send_entity(path, data, initheader, dest, Patch, &block)
    end

    def put(path, data, initheader = nil)   #:nodoc:
      request(Put.new(path, initheader), data)
    end

    def proppatch(path, body, initheader = nil)
      request(Proppatch.new(path, initheader), body)
    end

    def lock(path, body, initheader = nil)
      request(Lock.new(path, initheader), body)
    end

    def unlock(path, body, initheader = nil)
      request(Unlock.new(path, initheader), body)
    end

    def options(path, initheader = nil)
      request(Options.new(path, initheader))
    end

    def propfind(path, body = nil, initheader = {'Depth' => '0'})
      request(Propfind.new(path, initheader), body)
    end

    def delete(path, initheader = {'Depth' => 'Infinity'})
      request(Delete.new(path, initheader))
    end

    def move(path, initheader = nil)
      request(Move.new(path, initheader))
    end

    def copy(path, initheader = nil)
      request(Copy.new(path, initheader))
    end

    def mkcol(path, body = nil, initheader = nil)
      request(Mkcol.new(path, initheader), body)
    end

    def trace(path, initheader = nil)
      request(Trace.new(path, initheader))
    end

    def request_get(path, initheader = nil, &block) # :yield: +response+
      request(Get.new(path, initheader), &block)
    end

    def request_head(path, initheader = nil, &block)
      request(Head.new(path, initheader), &block)
    end

    def request_post(path, data, initheader = nil, &block) # :yield: +response+
      request Post.new(path, initheader), data, &block
    end

    def request_put(path, data, initheader = nil, &block)   #:nodoc:
      request Put.new(path, initheader), data, &block
    end

    alias get2   request_get    #:nodoc: obsolete
    alias head2  request_head   #:nodoc: obsolete
    alias post2  request_post   #:nodoc: obsolete
    alias put2   request_put    #:nodoc: obsolete


    def send_request(name, path, data = nil, header = nil)
      has_response_body = name != 'HEAD'
      r = HTTPGenericRequest.new(name,(data ? true : false),has_response_body,path,header)
      request r, data
    end

    def request(req, body = nil, &block)  # :yield: +response+
      unless started?
        start {
          req['connection'] ||= 'close'
          return request(req, body, &block)
        }
      end
      if proxy_user()
        req.proxy_basic_auth proxy_user(), proxy_pass() unless use_ssl?
      end
      req.set_body_internal body
      res = transport_request(req, &block)
      if sspi_auth?(res)
        sspi_auth(req)
        res = transport_request(req, &block)
      end
      res
    end

    private

    def send_entity(path, data, initheader, dest, type, &block)
      res = nil
      request(type.new(path, initheader), data) {|r|
        r.read_body dest, &block
        res = r
      }
      res
    end

    IDEMPOTENT_METHODS_ = %w/GET HEAD PUT DELETE OPTIONS TRACE/ # :nodoc:

    def transport_request(req)
      count = 0
      begin
        begin_transport req
        res = catch(:response) {
          req.exec @socket, @curr_http_version, edit_path(req.path)
          begin
            res = HTTPResponse.read_new(@socket)
            res.decode_content = req.decode_content
          end while res.kind_of?(HTTPContinue)

          res.uri = req.uri

          res.reading_body(@socket, req.response_body_permitted?) {
            yield res if block_given?
          }
          res
        }
      rescue Net::OpenTimeout
        raise
      rescue Net::ReadTimeout, IOError, EOFError,
             Errno::ECONNRESET, Errno::ECONNABORTED, Errno::EPIPE,
             defined?(OpenSSL::SSL) ? OpenSSL::SSL::SSLError : IOError,
             Timeout::Error => exception
        if count == 0 && IDEMPOTENT_METHODS_.include?(req.method)
          count += 1
          @socket.close if @socket and not @socket.closed?
          D "Conn close because of error #{exception}, and retry"
          retry
        end
        D "Conn close because of error #{exception}"
        @socket.close if @socket and not @socket.closed?
        raise
      end

      end_transport req, res
      res
    rescue => exception
      D "Conn close because of error #{exception}"
      @socket.close if @socket and not @socket.closed?
      raise exception
    end

    def begin_transport(req)
      if @socket.closed?
        connect
      elsif @last_communicated && @last_communicated + @keep_alive_timeout < Time.now
        D 'Conn close because of keep_alive_timeout'
        @socket.close
        connect
      end

      if not req.response_body_permitted? and @close_on_empty_response
        req['connection'] ||= 'close'
      end

      req.update_uri address, port, use_ssl?
      req['host'] ||= addr_port()
    end

    def end_transport(req, res)
      @curr_http_version = res.http_version
      @last_communicated = nil
      if @socket.closed?
        D 'Conn socket closed'
      elsif not res.body and @close_on_empty_response
        D 'Conn close'
        @socket.close
      elsif keep_alive?(req, res)
        D 'Conn keep-alive'
        @last_communicated = Time.now
      else
        D 'Conn close'
        @socket.close
      end
    end

    def keep_alive?(req, res)
      return false if req.connection_close?
      if @curr_http_version <= '1.0'
        res.connection_keep_alive?
      else   # HTTP/1.1 or later
        not res.connection_close?
      end
    end

    def sspi_auth?(res)
      return false unless @sspi_enabled
      if res.kind_of?(HTTPProxyAuthenticationRequired) and
          proxy? and res["Proxy-Authenticate"].include?("Negotiate")
        begin
          require 'win32/sspi'
          true
        rescue LoadError
          false
        end
      else
        false
      end
    end

    def sspi_auth(req)
      n = Win32::SSPI::NegotiateAuth.new
      req["Proxy-Authorization"] = "Negotiate #{n.get_initial_token}"
      req["Connection"] = "Keep-Alive"
      req["Proxy-Connection"] = "Keep-Alive"
      res = transport_request(req)
      authphrase = res["Proxy-Authenticate"]  or return res
      req["Proxy-Authorization"] = "Negotiate #{n.complete_authentication(authphrase)}"
    rescue => err
      raise HTTPAuthenticationError.new('HTTP authentication failed', err)
    end


    private

    def addr_port
      if use_ssl?
        address() + (port == HTTP.https_default_port ? '' : ":#{port()}")
      else
        address() + (port == HTTP.http_default_port ? '' : ":#{port()}")
      end
    end

    def D(msg)
      return unless @debug_output
      @debug_output << msg
      @debug_output << "\n"
    end
  end

end

require 'net/http/exceptions'

require 'net/http/header'

require 'net/http/generic_request'
require 'net/http/request'
require 'net/http/requests'

require 'net/http/response'
require 'net/http/responses'

require 'net/http/proxy_delta'

require 'net/http/backward'

