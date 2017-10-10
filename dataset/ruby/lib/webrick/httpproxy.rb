
require "webrick/httpserver"
require "net/http"

module WEBrick

  NullReader = Object.new # :nodoc:
  class << NullReader # :nodoc:
    def read(*args)
      nil
    end
    alias gets read
  end

  FakeProxyURI = Object.new # :nodoc:
  class << FakeProxyURI # :nodoc:
    def method_missing(meth, *args)
      if %w(scheme host port path query userinfo).member?(meth.to_s)
        return nil
      end
      super
    end
  end



  class HTTPProxyServer < HTTPServer


    def initialize(config={}, default=Config::HTTP)
      super(config, default)
      c = @config
      @via = "#{c[:HTTPVersion]} #{c[:ServerName]}:#{c[:Port]}"
    end

    def service(req, res)
      if req.request_method == "CONNECT"
        do_CONNECT(req, res)
      elsif req.unparsed_uri =~ %r!^http://!
        proxy_service(req, res)
      else
        super(req, res)
      end
    end

    def proxy_auth(req, res)
      if proc = @config[:ProxyAuthProc]
        proc.call(req, res)
      end
      req.header.delete("proxy-authorization")
    end

    def proxy_uri(req, res)
      return @config[:ProxyURI]
    end

    def proxy_service(req, res)
      proxy_auth(req, res)

      begin
        #nodyna <send-2225> <SD COMPLEX (change-prone variables)>
        self.send("do_#{req.request_method}", req, res)
      rescue NoMethodError
        raise HTTPStatus::MethodNotAllowed,
          "unsupported method `#{req.request_method}'."
      rescue => err
        logger.debug("#{err.class}: #{err.message}")
        raise HTTPStatus::ServiceUnavailable, err.message
      end

      if handler = @config[:ProxyContentHandler]
        handler.call(req, res)
      end
    end

    def do_CONNECT(req, res)
      proxy_auth(req, res)

      ua = Thread.current[:WEBrickSocket]  # User-Agent
      raise HTTPStatus::InternalServerError,
        "[BUG] cannot get socket" unless ua

      host, port = req.unparsed_uri.split(":", 2)
      if proxy = proxy_uri(req, res)
        proxy_request_line = "CONNECT #{host}:#{port} HTTP/1.0"
        if proxy.userinfo
          credentials = "Basic " + [proxy.userinfo].pack("m").delete("\n")
        end
        host, port = proxy.host, proxy.port
      end

      begin
        @logger.debug("CONNECT: upstream proxy is `#{host}:#{port}'.")
        os = TCPSocket.new(host, port)     # origin server

        if proxy
          @logger.debug("CONNECT: sending a Request-Line")
          os << proxy_request_line << CRLF
          @logger.debug("CONNECT: > #{proxy_request_line}")
          if credentials
            @logger.debug("CONNECT: sending a credentials")
            os << "Proxy-Authorization: " << credentials << CRLF
          end
          os << CRLF
          proxy_status_line = os.gets(LF)
          @logger.debug("CONNECT: read a Status-Line form the upstream server")
          @logger.debug("CONNECT: < #{proxy_status_line}")
          if %r{^HTTP/\d+\.\d+\s+200\s*} =~ proxy_status_line
            while line = os.gets(LF)
              break if /\A(#{CRLF}|#{LF})\z/om =~ line
            end
          else
            raise HTTPStatus::BadGateway
          end
        end
        @logger.debug("CONNECT #{host}:#{port}: succeeded")
        res.status = HTTPStatus::RC_OK
      rescue => ex
        @logger.debug("CONNECT #{host}:#{port}: failed `#{ex.message}'")
        res.set_error(ex)
        raise HTTPStatus::EOFError
      ensure
        if handler = @config[:ProxyContentHandler]
          handler.call(req, res)
        end
        res.send_response(ua)
        access_log(@config, req, res)

        req.parse(NullReader) rescue nil
      end

      begin
        while fds = IO::select([ua, os])
          if fds[0].member?(ua)
            buf = ua.sysread(1024);
            @logger.debug("CONNECT: #{buf.bytesize} byte from User-Agent")
            os.syswrite(buf)
          elsif fds[0].member?(os)
            buf = os.sysread(1024);
            @logger.debug("CONNECT: #{buf.bytesize} byte from #{host}:#{port}")
            ua.syswrite(buf)
          end
        end
      rescue
        os.close
        @logger.debug("CONNECT #{host}:#{port}: closed")
      end

      raise HTTPStatus::EOFError
    end

    def do_GET(req, res)
      perform_proxy_request(req, res) do |http, path, header|
        http.get(path, header)
      end
    end

    def do_HEAD(req, res)
      perform_proxy_request(req, res) do |http, path, header|
        http.head(path, header)
      end
    end

    def do_POST(req, res)
      perform_proxy_request(req, res) do |http, path, header|
        http.post(path, req.body || "", header)
      end
    end

    def do_OPTIONS(req, res)
      res['allow'] = "GET,HEAD,POST,OPTIONS,CONNECT"
    end

    private

    HopByHop = %w( connection keep-alive proxy-authenticate upgrade
                   proxy-authorization te trailers transfer-encoding )
    ShouldNotTransfer = %w( set-cookie proxy-connection )
    def split_field(f) f ? f.split(/,\s+/).collect{|i| i.downcase } : [] end

    def choose_header(src, dst)
      connections = split_field(src['connection'])
      src.each{|key, value|
        key = key.downcase
        if HopByHop.member?(key)          || # RFC2616: 13.5.1
           connections.member?(key)       || # RFC2616: 14.10
           ShouldNotTransfer.member?(key)    # pragmatics
          @logger.debug("choose_header: `#{key}: #{value}'")
          next
        end
        dst[key] = value
      }
    end

    def set_cookie(src, dst)
      if str = src['set-cookie']
        cookies = []
        str.split(/,\s*/).each{|token|
          if /^[^=]+;/o =~ token
            cookies[-1] << ", " << token
          elsif /=/o =~ token
            cookies << token
          else
            cookies[-1] << ", " << token
          end
        }
        dst.cookies.replace(cookies)
      end
    end

    def set_via(h)
      if @config[:ProxyVia]
        if  h['via']
          h['via'] << ", " << @via
        else
          h['via'] = @via
        end
      end
    end

    def setup_proxy_header(req, res)
      header = Hash.new
      choose_header(req, header)
      set_via(header)
      return header
    end

    def setup_upstream_proxy_authentication(req, res, header)
      if upstream = proxy_uri(req, res)
        if upstream.userinfo
          header['proxy-authorization'] =
            "Basic " + [upstream.userinfo].pack("m").delete("\n")
        end
        return upstream
      end
      return FakeProxyURI
    end

    def perform_proxy_request(req, res)
      uri = req.request_uri
      path = uri.path.dup
      path << "?" << uri.query if uri.query
      header = setup_proxy_header(req, res)
      upstream = setup_upstream_proxy_authentication(req, res, header)
      response = nil

      http = Net::HTTP.new(uri.host, uri.port, upstream.host, upstream.port)
      http.start do
        if @config[:ProxyTimeout]
          http.open_timeout = 30   # secs  #   necessary (maybe because
          http.read_timeout = 60   # secs  #   Ruby's bug, but why?)
        end
        response = yield(http, path, header)
      end

      res['proxy-connection'] = "close"
      res['connection'] = "close"

      res.status = response.code.to_i
      choose_header(response, res)
      set_cookie(response, res)
      set_via(res)
      res.body = response.body
    end

  end
end
