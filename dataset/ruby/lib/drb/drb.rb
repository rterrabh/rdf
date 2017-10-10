
require 'socket'
require 'thread'
require 'fcntl'
require 'drb/eq'

module DRb

  class DRbError < RuntimeError; end

  class DRbConnError < DRbError; end

  class DRbIdConv

    def to_obj(ref)
      ObjectSpace._id2ref(ref)
    end

    def to_id(obj)
      obj.nil? ? nil : obj.__id__
    end
  end

  module DRbUndumped
    def _dump(dummy)  # :nodoc:
      raise TypeError, 'can\'t dump'
    end
  end

  class DRbServerNotFound < DRbError; end

  class DRbBadURI < DRbError; end

  class DRbBadScheme < DRbError; end

  class DRbUnknownError < DRbError

    def initialize(unknown)
      @unknown = unknown
      super(unknown.name)
    end

    attr_reader :unknown

    def self._load(s)  # :nodoc:
      Marshal::load(s)
    end

    def _dump(lv) # :nodoc:
      Marshal::dump(@unknown)
    end
  end

  class DRbRemoteError < DRbError

    def initialize(error)
      @reason = error.class.to_s
      super("#{error.message} (#{error.class})")
      set_backtrace(error.backtrace)
    end

    attr_reader :reason
  end

  class DRbUnknown

    def initialize(err, buf)
      case err.to_s
      when /uninitialized constant (\S+)/
        @name = $1
      when /undefined class\/module (\S+)/
        @name = $1
      else
        @name = nil
      end
      @buf = buf
    end

    attr_reader :name

    attr_reader :buf

    def self._load(s) # :nodoc:
      begin
        Marshal::load(s)
      rescue NameError, ArgumentError
        DRbUnknown.new($!, s)
      end
    end

    def _dump(lv) # :nodoc:
      @buf
    end

    def reload
      self.class._load(@buf)
    end

    def exception
      DRbUnknownError.new(self)
    end
  end


  class DRbArray


    def initialize(ary)
      @ary = ary.collect { |obj|
        if obj.kind_of? DRbUndumped
          DRbObject.new(obj)
        else
          begin
            Marshal.dump(obj)
            obj
          rescue
            DRbObject.new(obj)
          end
        end
      }
    end

    def self._load(s) # :nodoc:
      Marshal::load(s)
    end

    def _dump(lv) # :nodoc:
      Marshal.dump(@ary)
    end
  end

  class DRbMessage
    def initialize(config) # :nodoc:
      @load_limit = config[:load_limit]
      @argc_limit = config[:argc_limit]
    end

    def dump(obj, error=false)  # :nodoc:
      obj = make_proxy(obj, error) if obj.kind_of? DRbUndumped
      begin
        str = Marshal::dump(obj)
      rescue
        str = Marshal::dump(make_proxy(obj, error))
      end
      [str.size].pack('N') + str
    end

    def load(soc)  # :nodoc:
      begin
        sz = soc.read(4)        # sizeof (N)
      rescue
        raise(DRbConnError, $!.message, $!.backtrace)
      end
      raise(DRbConnError, 'connection closed') if sz.nil?
      raise(DRbConnError, 'premature header') if sz.size < 4
      sz = sz.unpack('N')[0]
      raise(DRbConnError, "too large packet #{sz}") if @load_limit < sz
      begin
        str = soc.read(sz)
      rescue
        raise(DRbConnError, $!.message, $!.backtrace)
      end
      raise(DRbConnError, 'connection closed') if str.nil?
      raise(DRbConnError, 'premature marshal format(can\'t read)') if str.size < sz
      DRb.mutex.synchronize do
        begin
          save = Thread.current[:drb_untaint]
          Thread.current[:drb_untaint] = []
          Marshal::load(str)
        rescue NameError, ArgumentError
          DRbUnknown.new($!, str)
        ensure
          Thread.current[:drb_untaint].each do |x|
            x.untaint
          end
          Thread.current[:drb_untaint] = save
        end
      end
    end

    def send_request(stream, ref, msg_id, arg, b) # :nodoc:
      ary = []
      ary.push(dump(ref.__drbref))
      ary.push(dump(msg_id.id2name))
      ary.push(dump(arg.length))
      arg.each do |e|
        ary.push(dump(e))
      end
      ary.push(dump(b))
      stream.write(ary.join(''))
    rescue
      raise(DRbConnError, $!.message, $!.backtrace)
    end

    def recv_request(stream) # :nodoc:
      ref = load(stream)
      ro = DRb.to_obj(ref)
      msg = load(stream)
      argc = load(stream)
      raise(DRbConnError, "too many arguments") if @argc_limit < argc
      argv = Array.new(argc, nil)
      argc.times do |n|
        argv[n] = load(stream)
      end
      block = load(stream)
      return ro, msg, argv, block
    end

    def send_reply(stream, succ, result)  # :nodoc:
      stream.write(dump(succ) + dump(result, !succ))
    rescue
      raise(DRbConnError, $!.message, $!.backtrace)
    end

    def recv_reply(stream)  # :nodoc:
      succ = load(stream)
      result = load(stream)
      [succ, result]
    end

    private
    def make_proxy(obj, error=false) # :nodoc:
      if error
        DRbRemoteError.new(obj)
      else
        DRbObject.new(obj)
      end
    end
  end

  module DRbProtocol

    def add_protocol(prot)
      @protocol.push(prot)
    end
    module_function :add_protocol

    def open(uri, config, first=true)
      @protocol.each do |prot|
        begin
          return prot.open(uri, config)
        rescue DRbBadScheme
        rescue DRbConnError
          raise($!)
        rescue
          raise(DRbConnError, "#{uri} - #{$!.inspect}")
        end
      end
      if first && (config[:auto_load] != false)
        auto_load(uri, config)
        return open(uri, config, false)
      end
      raise DRbBadURI, 'can\'t parse uri:' + uri
    end
    module_function :open

    def open_server(uri, config, first=true)
      @protocol.each do |prot|
        begin
          return prot.open_server(uri, config)
        rescue DRbBadScheme
        end
      end
      if first && (config[:auto_load] != false)
        auto_load(uri, config)
        return open_server(uri, config, false)
      end
      raise DRbBadURI, 'can\'t parse uri:' + uri
    end
    module_function :open_server

    def uri_option(uri, config, first=true)
      @protocol.each do |prot|
        begin
          uri, opt = prot.uri_option(uri, config)
          return uri, opt
        rescue DRbBadScheme
        end
      end
      if first && (config[:auto_load] != false)
        auto_load(uri, config)
        return uri_option(uri, config, false)
      end
      raise DRbBadURI, 'can\'t parse uri:' + uri
    end
    module_function :uri_option

    def auto_load(uri, config)  # :nodoc:
      if uri =~ /^drb([a-z0-9]+):/
        require("drb/#{$1}") rescue nil
      end
    end
    module_function :auto_load
  end


  class DRbTCPSocket
    private
    def self.parse_uri(uri)
      if uri =~ /^druby:\/\/(.*?):(\d+)(\?(.*))?$/
        host = $1
        port = $2.to_i
        option = $4
        [host, port, option]
      else
        raise(DRbBadScheme, uri) unless uri =~ /^druby:/
        raise(DRbBadURI, 'can\'t parse uri:' + uri)
      end
    end

    public

    def self.open(uri, config)
      host, port, = parse_uri(uri)
      host.untaint
      port.untaint
      soc = TCPSocket.open(host, port)
      self.new(uri, soc, config)
    end

    def self.getservername
      host = Socket::gethostname
      begin
        Socket::gethostbyname(host)[0]
      rescue
        'localhost'
      end
    end

    def self.open_server_inaddr_any(host, port)
      infos = Socket::getaddrinfo(host, nil,
                                  Socket::AF_UNSPEC,
                                  Socket::SOCK_STREAM,
                                  0,
                                  Socket::AI_PASSIVE)
      families = Hash[*infos.collect { |af, *_| af }.uniq.zip([]).flatten]
      return TCPServer.open('0.0.0.0', port) if families.has_key?('AF_INET')
      return TCPServer.open('::', port) if families.has_key?('AF_INET6')
      return TCPServer.open(port)
    end

    def self.open_server(uri, config)
      uri = 'druby://:0' unless uri
      host, port, _ = parse_uri(uri)
      config = {:tcp_original_host => host}.update(config)
      if host.size == 0
        host = getservername
        soc = open_server_inaddr_any(host, port)
      else
        soc = TCPServer.open(host, port)
      end
      port = soc.addr[1] if port == 0
      config[:tcp_port] = port
      uri = "druby://#{host}:#{port}"
      self.new(uri, soc, config)
    end

    def self.uri_option(uri, config)
      host, port, option = parse_uri(uri)
      return "druby://#{host}:#{port}", option
    end

    def initialize(uri, soc, config={})
      @uri = uri
      @socket = soc
      @config = config
      @acl = config[:tcp_acl]
      @msg = DRbMessage.new(config)
      set_sockopt(@socket)
      @shutdown_pipe_r, @shutdown_pipe_w = IO.pipe
    end

    attr_reader :uri

    def peeraddr
      @socket.peeraddr
    end

    def stream; @socket; end

    def send_request(ref, msg_id, arg, b)
      @msg.send_request(stream, ref, msg_id, arg, b)
    end

    def recv_request
      @msg.recv_request(stream)
    end

    def send_reply(succ, result)
      @msg.send_reply(stream, succ, result)
    end

    def recv_reply
      @msg.recv_reply(stream)
    end

    public

    def close
      if @socket
        @socket.close
        @socket = nil
      end
      close_shutdown_pipe
    end

    def close_shutdown_pipe
      if @shutdown_pipe_r && !@shutdown_pipe_r.closed?
        @shutdown_pipe_r.close
        @shutdown_pipe_r = nil
      end
      if @shutdown_pipe_w && !@shutdown_pipe_w.closed?
        @shutdown_pipe_w.close
        @shutdown_pipe_w = nil
      end
    end
    private :close_shutdown_pipe

    def accept
      while true
        s = accept_or_shutdown
        return nil unless s
        break if (@acl ? @acl.allow_socket?(s) : true)
        s.close
      end
      if @config[:tcp_original_host].to_s.size == 0
        uri = "druby://#{s.addr[3]}:#{@config[:tcp_port]}"
      else
        uri = @uri
      end
      self.class.new(uri, s, @config)
    end

    def accept_or_shutdown
      readables, = IO.select([@socket, @shutdown_pipe_r])
      if readables.include? @shutdown_pipe_r
        return nil
      end
      @socket.accept
    end
    private :accept_or_shutdown

    def shutdown
      @shutdown_pipe_w.close if @shutdown_pipe_w && !@shutdown_pipe_w.closed?
    end

    def alive?
      return false unless @socket
      if IO.select([@socket], nil, nil, 0)
        close
        return false
      end
      true
    end

    def set_sockopt(soc) # :nodoc:
      soc.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)
      soc.fcntl(Fcntl::F_SETFD, Fcntl::FD_CLOEXEC) if defined? Fcntl::FD_CLOEXEC
    end
  end

  module DRbProtocol
    @protocol = [DRbTCPSocket] # default
  end

  class DRbURIOption  # :nodoc:  I don't understand the purpose of this class...
    def initialize(option)
      @option = option.to_s
    end
    attr_reader :option
    def to_s; @option; end

    def ==(other)
      return false unless DRbURIOption === other
      @option == other.option
    end

    def hash
      @option.hash
    end

    alias eql? ==
  end

  class DRbObject

    def self._load(s)
      uri, ref = Marshal.load(s)

      if DRb.here?(uri)
        obj = DRb.to_obj(ref)
        if ((! obj.tainted?) && Thread.current[:drb_untaint])
          Thread.current[:drb_untaint].push(obj)
        end
        return obj
      end

      self.new_with(uri, ref)
    end


    def self.new_with(uri, ref)
      it = self.allocate
      #nodyna <instance_variable_set-2047> <not yet classified>
      it.instance_variable_set(:@uri, uri)
      #nodyna <instance_variable_set-2048> <not yet classified>
      it.instance_variable_set(:@ref, ref)
      it
    end

    def self.new_with_uri(uri)
      self.new(nil, uri)
    end

    def _dump(lv)
      Marshal.dump([@uri, @ref])
    end

    def initialize(obj, uri=nil)
      @uri = nil
      @ref = nil
      if obj.nil?
        return if uri.nil?
        @uri, option = DRbProtocol.uri_option(uri, DRb.config)
        @ref = DRbURIOption.new(option) unless option.nil?
      else
        @uri = uri ? uri : (DRb.uri rescue nil)
        @ref = obj ? DRb.to_id(obj) : nil
      end
    end

    def __drburi
      @uri
    end

    def __drbref
      @ref
    end

    undef :to_s
    undef :to_a if respond_to?(:to_a)

    def respond_to?(msg_id, priv=false)
      case msg_id
      when :_dump
        true
      when :marshal_dump
        false
      else
        method_missing(:respond_to?, msg_id, priv)
      end
    end

    def method_missing(msg_id, *a, &b)
      if DRb.here?(@uri)
        obj = DRb.to_obj(@ref)
        DRb.current_server.check_insecure_method(obj, msg_id)
        return obj.__send__(msg_id, *a, &b)
      end

      succ, result = self.class.with_friend(@uri) do
        DRbConn.open(@uri) do |conn|
          conn.send_message(self, msg_id, a, b)
        end
      end

      if succ
        return result
      elsif DRbUnknown === result
        raise result
      else
        bt = self.class.prepare_backtrace(@uri, result)
        result.set_backtrace(bt + caller)
        raise result
      end
    end

    def self.with_friend(uri) # :nodoc:
      friend = DRb.fetch_server(uri)
      return yield() unless friend

      save = Thread.current['DRb']
      Thread.current['DRb'] = { 'server' => friend }
      return yield
    ensure
      Thread.current['DRb'] = save if friend
    end

    def self.prepare_backtrace(uri, result) # :nodoc:
      prefix = "(#{uri}) "
      bt = []
      result.backtrace.each do |x|
        break if /`__send__'$/ =~ x
        if /^\(druby:\/\// =~ x
          bt.push(x)
        else
          bt.push(prefix + x)
        end
      end
      bt
    end

    def pretty_print(q)   # :nodoc:
      q.pp_object(self)
    end

    def pretty_print_cycle(q)   # :nodoc:
      q.object_address_group(self) {
        q.breakable
        q.text '...'
      }
    end
  end

  class DRbConn
    POOL_SIZE = 16  # :nodoc:
    @mutex = Mutex.new
    @pool = []

    def self.open(remote_uri)  # :nodoc:
      begin
        conn = nil

        @mutex.synchronize do
          new_pool = []
          @pool.each do |c|
            if conn.nil? and c.uri == remote_uri
              conn = c if c.alive?
            else
              new_pool.push c
            end
          end
          @pool = new_pool
        end

        conn = self.new(remote_uri) unless conn
        succ, result = yield(conn)
        return succ, result

      ensure
        if conn
          if succ
            @mutex.synchronize do
              @pool.unshift(conn)
              @pool.pop.close while @pool.size > POOL_SIZE
            end
          else
            conn.close
          end
        end
      end
    end

    def initialize(remote_uri)  # :nodoc:
      @uri = remote_uri
      @protocol = DRbProtocol.open(remote_uri, DRb.config)
    end
    attr_reader :uri  # :nodoc:

    def send_message(ref, msg_id, arg, block)  # :nodoc:
      @protocol.send_request(ref, msg_id, arg, block)
      @protocol.recv_reply
    end

    def close  # :nodoc:
      @protocol.close
      @protocol = nil
    end

    def alive?  # :nodoc:
      return false unless @protocol
      @protocol.alive?
    end
  end

  class DRbServer
    @@acl = nil
    @@idconv = DRbIdConv.new
    @@secondary_server = nil
    @@argc_limit = 256
    @@load_limit = 256 * 102400
    @@verbose = false
    @@safe_level = 0

    def self.default_argc_limit(argc)
      @@argc_limit = argc
    end

    def self.default_load_limit(sz)
      @@load_limit = sz
    end

    def self.default_acl(acl)
      @@acl = acl
    end

    def self.default_id_conv(idconv)
      @@idconv = idconv
    end

    def self.default_safe_level(level)
      @@safe_level = level
    end

    def self.verbose=(on)
      @@verbose = on
    end

    def self.verbose
      @@verbose
    end

    def self.make_config(hash={})  # :nodoc:
      default_config = {
        :idconv => @@idconv,
        :verbose => @@verbose,
        :tcp_acl => @@acl,
        :load_limit => @@load_limit,
        :argc_limit => @@argc_limit,
        :safe_level => @@safe_level
      }
      default_config.update(hash)
    end

    def initialize(uri=nil, front=nil, config_or_acl=nil)
      if Hash === config_or_acl
        config = config_or_acl.dup
      else
        acl = config_or_acl || @@acl
        config = {
          :tcp_acl => acl
        }
      end

      @config = self.class.make_config(config)

      @protocol = DRbProtocol.open_server(uri, @config)
      @uri = @protocol.uri
      @exported_uri = [@uri]

      @front = front
      @idconv = @config[:idconv]
      @safe_level = @config[:safe_level]

      @grp = ThreadGroup.new
      @thread = run

      DRb.regist_server(self)
    end

    attr_reader :uri

    attr_reader :thread

    attr_reader :front

    attr_reader :config

    attr_reader :safe_level

    def verbose=(v); @config[:verbose]=v; end

    def verbose; @config[:verbose]; end

    def alive?
      @thread.alive?
    end

    def here?(uri)
      @exported_uri.include?(uri)
    end

    def stop_service
      DRb.remove_server(self)
      if  Thread.current['DRb'] && Thread.current['DRb']['server'] == self
        Thread.current['DRb']['stop_service'] = true
      else
        if @protocol.respond_to? :shutdown
          @protocol.shutdown
        else
          @thread.kill # xxx: Thread#kill
        end
        @thread.join
      end
    end

    def to_obj(ref)
      return front if ref.nil?
      return front[ref.to_s] if DRbURIOption === ref
      @idconv.to_obj(ref)
    end

    def to_id(obj)
      return nil if obj.__id__ == front.__id__
      @idconv.to_id(obj)
    end

    private


    def run
      Thread.start do
        begin
          while main_loop
          end
        ensure
          @protocol.close if @protocol
        end
      end
    end

    INSECURE_METHOD = [
      :__send__
    ]

    def insecure_method?(msg_id)
      INSECURE_METHOD.include?(msg_id)
    end

    def any_to_s(obj)
      obj.to_s + ":#{obj.class}"
    rescue
      sprintf("#<%s:0x%lx>", obj.class, obj.__id__)
    end

    def check_insecure_method(obj, msg_id)
      return true if Proc === obj && msg_id == :__drb_yield
      raise(ArgumentError, "#{any_to_s(msg_id)} is not a symbol") unless Symbol == msg_id.class
      raise(SecurityError, "insecure method `#{msg_id}'") if insecure_method?(msg_id)

      if obj.private_methods.include?(msg_id)
        desc = any_to_s(obj)
        raise NoMethodError, "private method `#{msg_id}' called for #{desc}"
      elsif obj.protected_methods.include?(msg_id)
        desc = any_to_s(obj)
        raise NoMethodError, "protected method `#{msg_id}' called for #{desc}"
      else
        true
      end
    end
    public :check_insecure_method

    class InvokeMethod  # :nodoc:
      def initialize(drb_server, client)
        @drb_server = drb_server
        @safe_level = drb_server.safe_level
        @client = client
      end

      def perform
        @result = nil
        @succ = false
        setup_message

        if $SAFE < @safe_level
          info = Thread.current['DRb']
          if @block
            @result = Thread.new {
              Thread.current['DRb'] = info
              $SAFE = @safe_level
              perform_with_block
            }.value
          else
            @result = Thread.new {
              Thread.current['DRb'] = info
              $SAFE = @safe_level
              perform_without_block
            }.value
          end
        else
          if @block
            @result = perform_with_block
          else
            @result = perform_without_block
          end
        end
        @succ = true
        if @msg_id == :to_ary && @result.class == Array
          @result = DRbArray.new(@result)
        end
        return @succ, @result
      rescue StandardError, ScriptError, Interrupt
        @result = $!
        return @succ, @result
      end

      private
      def init_with_client
        obj, msg, argv, block = @client.recv_request
        @obj = obj
        @msg_id = msg.intern
        @argv = argv
        @block = block
      end

      def check_insecure_method
        @drb_server.check_insecure_method(@obj, @msg_id)
      end

      def setup_message
        init_with_client
        check_insecure_method
      end

      def perform_without_block
        if Proc === @obj && @msg_id == :__drb_yield
          if @argv.size == 1
            ary = @argv
          else
            ary = [@argv]
          end
          ary.collect(&@obj)[0]
        else
          @obj.__send__(@msg_id, *@argv)
        end
      end

    end

    require 'drb/invokemethod'
    class InvokeMethod
      include InvokeMethod18Mixin
    end

    def main_loop
      client0 = @protocol.accept
      return nil if !client0
      Thread.start(client0) do |client|
        @grp.add Thread.current
        Thread.current['DRb'] = { 'client' => client ,
                                  'server' => self }
        DRb.mutex.synchronize do
          client_uri = client.uri
          @exported_uri << client_uri unless @exported_uri.include?(client_uri)
        end
        loop do
          begin
            succ = false
            invoke_method = InvokeMethod.new(self, client)
            succ, result = invoke_method.perform
            if !succ && verbose
              p result
              result.backtrace.each do |x|
                puts x
              end
            end
            client.send_reply(succ, result) rescue nil
          ensure
            client.close unless succ
            if Thread.current['DRb']['stop_service']
              Thread.new { stop_service }
            end
            break unless succ
          end
        end
      end
    end
  end

  @primary_server = nil

  def start_service(uri=nil, front=nil, config=nil)
    @primary_server = DRbServer.new(uri, front, config)
  end
  module_function :start_service

  attr_accessor :primary_server
  module_function :primary_server=, :primary_server

  def current_server
    drb = Thread.current['DRb']
    server = (drb && drb['server']) ? drb['server'] : @primary_server
    raise DRbServerNotFound unless server
    return server
  end
  module_function :current_server

  def stop_service
    @primary_server.stop_service if @primary_server
    @primary_server = nil
  end
  module_function :stop_service

  def uri
    drb = Thread.current['DRb']
    client = (drb && drb['client'])
    if client
      uri = client.uri
      return uri if uri
    end
    current_server.uri
  end
  module_function :uri

  def here?(uri)
    current_server.here?(uri) rescue false
  end
  module_function :here?

  def config
    current_server.config
  rescue
    DRbServer.make_config
  end
  module_function :config

  def front
    current_server.front
  end
  module_function :front

  def to_obj(ref)
    current_server.to_obj(ref)
  end

  def to_id(obj)
    current_server.to_id(obj)
  end
  module_function :to_id
  module_function :to_obj

  def thread
    @primary_server ? @primary_server.thread : nil
  end
  module_function :thread

  def install_id_conv(idconv)
    DRbServer.default_id_conv(idconv)
  end
  module_function :install_id_conv

  def install_acl(acl)
    DRbServer.default_acl(acl)
  end
  module_function :install_acl

  @mutex = Mutex.new
  def mutex # :nodoc:
    @mutex
  end
  module_function :mutex

  @server = {}
  def regist_server(server)
    @server[server.uri] = server
    mutex.synchronize do
      @primary_server = server unless @primary_server
    end
  end
  module_function :regist_server

  def remove_server(server)
    @server.delete(server.uri)
  end
  module_function :remove_server

  def fetch_server(uri)
    @server[uri]
  end
  module_function :fetch_server
end

DRbObject = DRb::DRbObject
DRbUndumped = DRb::DRbUndumped
DRbIdConv = DRb::DRbIdConv
