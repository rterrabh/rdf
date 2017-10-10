require "xmlrpc/parser"
require "xmlrpc/create"
require "xmlrpc/config"
require "xmlrpc/utils"     # ParserWriterChooseMixin
require "net/http"
require "uri"

module XMLRPC # :nodoc:

  class Client

    USER_AGENT = "XMLRPC::Client (Ruby #{RUBY_VERSION})"

    include ParserWriterChooseMixin
    include ParseContentType


    def initialize(host=nil, path=nil, port=nil, proxy_host=nil, proxy_port=nil,
                   user=nil, password=nil, use_ssl=nil, timeout=nil)

      @http_header_extra = nil
      @http_last_response = nil
      @cookie = nil

      @host       = host || "localhost"
      @path       = path || "/RPC2"
      @proxy_host = proxy_host
      @proxy_port = proxy_port
      @proxy_host ||= 'localhost' if @proxy_port != nil
      @proxy_port ||= 8080 if @proxy_host != nil
      @use_ssl    = use_ssl || false
      @timeout    = timeout || 30

      if use_ssl
        require "net/https"
        @port = port || 443
      else
        @port = port || 80
      end

      @user, @password = user, password

      set_auth

      @port = @port.to_i if @port != nil
      @proxy_port = @proxy_port.to_i if @proxy_port != nil

      @http = net_http(@host, @port, @proxy_host, @proxy_port)
      @http.use_ssl = @use_ssl if @use_ssl
      @http.read_timeout = @timeout
      @http.open_timeout = @timeout

      @parser = nil
      @create = nil
    end


    class << self

    def new2(uri, proxy=nil, timeout=nil)
      begin
        url = URI(uri)
      rescue URI::InvalidURIError => e
        raise ArgumentError, e.message, e.backtrace
      end

      unless URI::HTTP === url
        raise ArgumentError, "Wrong protocol specified. Only http or https allowed!"
      end

      proto  = url.scheme
      user   = url.user
      passwd = url.password
      host   = url.host
      port   = url.port
      path   = url.path.empty? ? nil : url.request_uri

      proxy_host, proxy_port = (proxy || "").split(":")
      proxy_port = proxy_port.to_i if proxy_port

      self.new(host, path, port, proxy_host, proxy_port, user, passwd, (proto == "https"), timeout)
    end

    alias new_from_uri new2

    def new3(hash={})

      h = {}
      hash.each { |k,v| h[k.to_s.downcase] = v }

      self.new(h['host'], h['path'], h['port'], h['proxy_host'], h['proxy_port'], h['user'], h['password'],
               h['use_ssl'], h['timeout'])
    end

    alias new_from_hash new3

    end


    attr_reader :http

    attr_accessor :http_header_extra

    attr_reader :http_last_response

    attr_accessor :cookie


    attr_reader :timeout, :user, :password

    def timeout=(new_timeout)
      @timeout = new_timeout
      @http.read_timeout = @timeout
      @http.open_timeout = @timeout
    end

    def user=(new_user)
      @user = new_user
      set_auth
    end

    def password=(new_password)
      @password = new_password
      set_auth
    end

    def call(method, *args)
      ok, param = call2(method, *args)
      if ok
        param
      else
        raise param
      end
    end

    def call2(method, *args)
      request = create().methodCall(method, *args)
      data = do_rpc(request, false)
      parser().parseMethodResponse(data)
    end

    def call_async(method, *args)
      ok, param = call2_async(method, *args)
      if ok
        param
      else
        raise param
      end
    end

    def call2_async(method, *args)
      request = create().methodCall(method, *args)
      data = do_rpc(request, true)
      parser().parseMethodResponse(data)
    end


    def multicall(*methods)
      ok, params = multicall2(*methods)
      if ok
        params
      else
        raise params
      end
    end

    def multicall2(*methods)
      gen_multicall(methods, false)
    end

    def multicall_async(*methods)
      ok, params = multicall2_async(*methods)
      if ok
        params
      else
        raise params
      end
    end

    def multicall2_async(*methods)
      gen_multicall(methods, true)
    end


    def proxy(prefix=nil, *args)
      Proxy.new(self, prefix, args, :call)
    end

    def proxy2(prefix=nil, *args)
      Proxy.new(self, prefix, args, :call2)
    end

    def proxy_async(prefix=nil, *args)
      Proxy.new(self, prefix, args, :call_async)
    end

    def proxy2_async(prefix=nil, *args)
      Proxy.new(self, prefix, args, :call2_async)
    end


    private

    def net_http(host, port, proxy_host, proxy_port)
      Net::HTTP.new host, port, proxy_host, proxy_port
    end

    def set_auth
      if @user.nil?
        @auth = nil
      else
        a =  "#@user"
        a << ":#@password" if @password != nil
        @auth = "Basic " + [a].pack("m0")
      end
    end

    def do_rpc(request, async=false)
      header = {
       "User-Agent"     =>  USER_AGENT,
       "Content-Type"   => "text/xml; charset=utf-8",
       "Content-Length" => request.bytesize.to_s,
       "Connection"     => (async ? "close" : "keep-alive")
      }

      header["Cookie"] = @cookie        if @cookie
      header.update(@http_header_extra) if @http_header_extra

      if @auth != nil
        header["Authorization"] = @auth
      end

      resp = nil
      @http_last_response = nil

      if async
        http = net_http(@host, @port, @proxy_host, @proxy_port)
        http.use_ssl = @use_ssl if @use_ssl
        http.read_timeout = @timeout
        http.open_timeout = @timeout

        http.start {
          resp = http.request_post(@path, request, header)
        }
      else
        @http.start if not @http.started?

        resp = @http.request_post(@path, request, header)
      end

      @http_last_response = resp

      data = resp.body

      if resp.code == "401"
        raise "Authorization failed.\nHTTP-Error: #{resp.code} #{resp.message}"
      elsif resp.code[0,1] != "2"
        raise "HTTP-Error: #{resp.code} #{resp.message}"
      end

      ct_expected = resp["Content-Type"] || 'text/xml'
      ct = parse_content_type(ct_expected).first
      if ct != "text/xml"
        if ct == "text/html"
          raise "Wrong content-type (received '#{ct}' but expected 'text/xml'): \n#{data}"
        else
          raise "Wrong content-type (received '#{ct}' but expected 'text/xml')"
        end
      end

      expected = resp["Content-Length"] || "<unknown>"
      if data.nil? or data.bytesize == 0
        raise "Wrong size. Was #{data.bytesize}, should be #{expected}"
      end

      parse_set_cookies(resp.get_fields("Set-Cookie"))

      return data
    end

    def parse_set_cookies(set_cookies)
      return if set_cookies.nil?
      return if set_cookies.empty?
      require 'webrick/cookie'
      pairs = {}
      set_cookies.each do |set_cookie|
        cookie = WEBrick::Cookie.parse_set_cookie(set_cookie)
        pairs.delete(cookie.name)
        pairs[cookie.name] = cookie.value
      end
      cookies = pairs.collect do |name, value|
        WEBrick::Cookie.new(name, value).to_s
      end
      @cookie = cookies.join("; ")
    end

    def gen_multicall(methods=[], async=false)
      meth = :call2
      meth = :call2_async if async

      #nodyna <send-2017> <SD EASY (change-prone variables)>
      ok, params = self.send(meth, "system.multicall",
        methods.collect {|m| {'methodName' => m[0], 'params' => m[1..-1]} }
      )

      if ok
        params = params.collect do |param|
          if param.is_a? Array
            param[0]
          elsif param.is_a? Hash
            XMLRPC::FaultException.new(param["faultCode"], param["faultString"])
          else
            raise "Wrong multicall return value"
          end
        end
      end

      return ok, params
    end



    class Proxy

      def initialize(server, prefix, args=[], meth=:call, delim=".")
        @server = server
        @prefix = prefix ? prefix + delim : ""
        @args   = args
        @meth   = meth
      end

      def method_missing(mid, *args)
        pre = @prefix + mid.to_s
        arg = @args + args
        #nodyna <send-2018> <SD COMPLEX (change-prone variables)>
        @server.send(@meth, pre, *arg)
      end

    end # class Proxy

  end # class Client

end # module XMLRPC

