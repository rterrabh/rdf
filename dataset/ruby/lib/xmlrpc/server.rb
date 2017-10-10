
require "xmlrpc/parser"
require "xmlrpc/create"
require "xmlrpc/config"
require "xmlrpc/utils"         # ParserWriterChooseMixin



module XMLRPC # :nodoc:


class BasicServer

  include ParserWriterChooseMixin
  include ParseContentType

  ERR_METHOD_MISSING        = 1
  ERR_UNCAUGHT_EXCEPTION    = 2
  ERR_MC_WRONG_PARAM        = 3
  ERR_MC_MISSING_PARAMS     = 4
  ERR_MC_MISSING_METHNAME   = 5
  ERR_MC_RECURSIVE_CALL     = 6
  ERR_MC_WRONG_PARAM_PARAMS = 7
  ERR_MC_EXPECTED_STRUCT    = 8


  def initialize(class_delim=".")
    @handler = []
    @default_handler = nil
    @service_hook = nil

    @class_delim = class_delim
    @create = nil
    @parser = nil

    add_multicall     if Config::ENABLE_MULTICALL
    add_introspection if Config::ENABLE_INTROSPECTION
  end

  def add_handler(prefix, obj_or_signature=nil, help=nil, &block)
    if block_given?
      @handler << [prefix, block, obj_or_signature, help]
    else
      if prefix.kind_of? String
        raise ArgumentError, "Expected non-nil value" if obj_or_signature.nil?
        @handler << [prefix + @class_delim, obj_or_signature]
      elsif prefix.kind_of? XMLRPC::Service::BasicInterface
        @handler += prefix.get_methods(obj_or_signature, @class_delim)
      else
        raise ArgumentError, "Wrong type for parameter 'prefix'"
      end
    end
    self
  end

  def get_service_hook
    @service_hook
  end

  def set_service_hook(&handler)
    @service_hook = handler
    self
  end

  def get_default_handler
    @default_handler
  end

  def set_default_handler(&handler)
    @default_handler = handler
    self
  end

  def add_multicall
    add_handler("system.multicall", %w(array array), "Multicall Extension") do |arrStructs|
      unless arrStructs.is_a? Array
        raise XMLRPC::FaultException.new(ERR_MC_WRONG_PARAM, "system.multicall expects an array")
      end

      arrStructs.collect {|call|
        if call.is_a? Hash
          methodName = call["methodName"]
          params     = call["params"]

          if params.nil?
            multicall_fault(ERR_MC_MISSING_PARAMS, "Missing params")
          elsif methodName.nil?
            multicall_fault(ERR_MC_MISSING_METHNAME, "Missing methodName")
          else
            if methodName == "system.multicall"
              multicall_fault(ERR_MC_RECURSIVE_CALL, "Recursive system.multicall forbidden")
            else
              unless params.is_a? Array
                multicall_fault(ERR_MC_WRONG_PARAM_PARAMS, "Parameter params have to be an Array")
              else
                ok, val = call_method(methodName, *params)
                if ok
                  [val]
                else
                  multicall_fault(val.faultCode, val.faultString)
                end
              end
            end
          end

        else
          multicall_fault(ERR_MC_EXPECTED_STRUCT, "system.multicall expected struct")
        end
      }
    end # end add_handler
    self
  end

  def add_introspection
    add_handler("system.listMethods",%w(array), "List methods available on this XML-RPC server") do
      methods = []
      @handler.each do |name, obj|
        if obj.kind_of? Proc
          methods << name
        else
          obj.class.public_instance_methods(false).each do |meth|
            methods << "#{name}#{meth}"
          end
        end
      end
      methods
    end

    add_handler("system.methodSignature", %w(array string), "Returns method signature") do |meth|
      sigs = []
      @handler.each do |name, obj, sig|
        if obj.kind_of? Proc and sig != nil and name == meth
          if sig[0].kind_of? Array
            sig.each {|s| sigs << s}
          else
            sigs << sig
          end
        end
      end
      sigs.uniq! || sigs  # remove eventually duplicated signatures
    end

    add_handler("system.methodHelp", %w(string string), "Returns help on using this method") do |meth|
      help = nil
      @handler.each do |name, obj, sig, hlp|
        if obj.kind_of? Proc and name == meth
          help = hlp
          break
        end
      end
      help || ""
    end

    self
  end



  def process(data)
    method, params = parser().parseMethodCall(data)
    handle(method, *params)
  end

  private

  def multicall_fault(nr, str)
    {"faultCode" => nr, "faultString" => str}
  end

  def dispatch(methodname, *args)
    for name, obj in @handler
      if obj.kind_of? Proc
        next unless methodname == name
      else
        next unless methodname =~ /^#{name}(.+)$/
        next unless obj.respond_to? $1
        obj = obj.method($1)
      end

      if check_arity(obj, args.size)
        if @service_hook.nil?
          return obj.call(*args)
        else
          return @service_hook.call(obj, *args)
        end
      end
    end

    if @default_handler.nil?
      raise XMLRPC::FaultException.new(ERR_METHOD_MISSING, "Method #{methodname} missing or wrong number of parameters!")
    else
      @default_handler.call(methodname, *args)
    end
  end


  def check_arity(obj, n_args)
    ary = obj.arity

    if ary >= 0
      n_args == ary
    else
      n_args >= (ary+1).abs
    end
  end



  def call_method(methodname, *args)
    begin
      [true, dispatch(methodname, *args)]
    rescue XMLRPC::FaultException => e
      [false, e]
    rescue Exception => e
      [false, XMLRPC::FaultException.new(ERR_UNCAUGHT_EXCEPTION, "Uncaught exception #{e.message} in method #{methodname}")]
    end
  end

  def handle(methodname, *args)
    create().methodResponse(*call_method(methodname, *args))
  end


end


class CGIServer < BasicServer
  @@obj = nil

  def CGIServer.new(*a)
    @@obj = super(*a) if @@obj.nil?
    @@obj
  end

  def initialize(*a)
    super(*a)
  end

  def serve
    catch(:exit_serve) {
      length = ENV['CONTENT_LENGTH'].to_i

      http_error(405, "Method Not Allowed") unless ENV['REQUEST_METHOD'] == "POST"
      http_error(400, "Bad Request")        unless parse_content_type(ENV['CONTENT_TYPE']).first == "text/xml"
      http_error(411, "Length Required")    unless length > 0

      $stdin.binmode if $stdin.respond_to? :binmode
      data = $stdin.read(length)

      http_error(400, "Bad Request")        if data.nil? or data.bytesize != length

      http_write(process(data), "Content-type" => "text/xml; charset=utf-8")
    }
  end


  private

  def http_error(status, message)
    err = "#{status} #{message}"
    msg = <<-"MSGEND"
      <html>
        <head>
          <title>#{err}</title>
        </head>
        <body>
          <h1>#{err}</h1>
          <p>Unexpected error occurred while processing XML-RPC request!</p>
        </body>
      </html>
    MSGEND

    http_write(msg, "Status" => err, "Content-type" => "text/html")
    throw :exit_serve # exit from the #serve method
  end

  def http_write(body, header)
    h = {}
    header.each {|key, value| h[key.to_s.capitalize] = value}
    h['Status']         ||= "200 OK"
    h['Content-length'] ||= body.bytesize.to_s

    str = ""
    h.each {|key, value| str << "#{key}: #{value}\r\n"}
    str << "\r\n#{body}"

    print str
  end

end


class ModRubyServer < BasicServer

  def initialize(*a)
    @ap = Apache::request
    super(*a)
  end

  def serve
    catch(:exit_serve) {
      header = {}
      @ap.headers_in.each {|key, value| header[key.capitalize] = value}

      length = header['Content-length'].to_i

      http_error(405, "Method Not Allowed") unless @ap.request_method  == "POST"
      http_error(400, "Bad Request")        unless parse_content_type(header['Content-type']).first == "text/xml"
      http_error(411, "Length Required")    unless length > 0

      @ap.binmode
      data = @ap.read(length)

      http_error(400, "Bad Request")        if data.nil? or data.bytesize != length

      http_write(process(data), 200, "Content-type" => "text/xml; charset=utf-8")
    }
  end


  private

  def http_error(status, message)
    err = "#{status} #{message}"
    msg = <<-"MSGEND"
      <html>
        <head>
          <title>#{err}</title>
        </head>
        <body>
          <h1>#{err}</h1>
          <p>Unexpected error occurred while processing XML-RPC request!</p>
        </body>
      </html>
    MSGEND

    http_write(msg, status, "Status" => err, "Content-type" => "text/html")
    throw :exit_serve # exit from the #serve method
  end

  def http_write(body, status, header)
    h = {}
    header.each {|key, value| h[key.to_s.capitalize] = value}
    h['Status']         ||= "200 OK"
    h['Content-length'] ||= body.bytesize.to_s

    h.each {|key, value| @ap.headers_out[key] = value }
    @ap.content_type = h["Content-type"]
    @ap.status = status.to_i
    @ap.send_http_header

    @ap.print body
  end

end


class WEBrickServlet < BasicServer; end # forward declaration

class Server < WEBrickServlet

  def initialize(port=8080, host="127.0.0.1", maxConnections=4, stdlog=$stdout, audit=true, debug=true, *a)
    super(*a)
    require 'webrick'
    @server = WEBrick::HTTPServer.new(:Port => port, :BindAddress => host, :MaxClients => maxConnections,
                                      :Logger => WEBrick::Log.new(stdlog))
    @server.mount("/", self)
  end

  def serve
    signals = %w[INT TERM HUP] & Signal.list.keys
    signals.each { |signal| trap(signal) { @server.shutdown } }

    @server.start
  end

  def shutdown
    @server.shutdown
  end

end


class WEBrickServlet < BasicServer
  def initialize(*a)
    super
    require "webrick/httpstatus"
    @valid_ip = nil
  end

  def require_path_info?
    false
  end

  def get_instance(config, *options)
    self
  end

  def set_valid_ip(*ip_addr)
    if ip_addr.size == 1 and ip_addr[0].nil?
      @valid_ip = nil
    else
      @valid_ip = ip_addr
    end
  end

  def get_valid_ip
    @valid_ip
  end

  def service(request, response)

    if @valid_ip
      raise WEBrick::HTTPStatus::Forbidden unless @valid_ip.any? { |ip| request.peeraddr[3] =~ ip }
    end

    if request.request_method != "POST"
      raise WEBrick::HTTPStatus::MethodNotAllowed,
            "unsupported method `#{request.request_method}'."
    end

    if parse_content_type(request['Content-type']).first != "text/xml"
      raise WEBrick::HTTPStatus::BadRequest
    end

    length = (request['Content-length'] || 0).to_i

    raise WEBrick::HTTPStatus::LengthRequired unless length > 0

    data = request.body

    if data.nil? or data.bytesize != length
      raise WEBrick::HTTPStatus::BadRequest
    end

    resp = process(data)
    if resp.nil? or resp.bytesize <= 0
      raise WEBrick::HTTPStatus::InternalServerError
    end

    response.status = 200
    response['Content-Length'] = resp.bytesize
    response['Content-Type']   = "text/xml; charset=utf-8"
    response.body = resp
  end
end


end # module XMLRPC


=begin
= History
    $Id$
=end

