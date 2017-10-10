require 'socket.so'

class Addrinfo
  def family_addrinfo(*args)
    if args.empty?
      raise ArgumentError, "no address specified"
    elsif Addrinfo === args.first
      raise ArgumentError, "too many arguments" if args.length != 1
      addrinfo = args.first
      if (self.pfamily != addrinfo.pfamily) ||
         (self.socktype != addrinfo.socktype)
        raise ArgumentError, "Addrinfo type mismatch"
      end
      addrinfo
    elsif self.ip?
      raise ArgumentError, "IP address needs host and port but #{args.length} arguments given" if args.length != 2
      host, port = args
      Addrinfo.getaddrinfo(host, port, self.pfamily, self.socktype, self.protocol)[0]
    elsif self.unix?
      raise ArgumentError, "UNIX socket needs single path argument but #{args.length} arguments given" if args.length != 1
      path, = args
      Addrinfo.unix(path)
    else
      raise ArgumentError, "unexpected family"
    end
  end

  def connect_internal(local_addrinfo, timeout=nil) # :yields: socket
    sock = Socket.new(self.pfamily, self.socktype, self.protocol)
    begin
      sock.ipv6only! if self.ipv6?
      sock.bind local_addrinfo if local_addrinfo
      if timeout
        begin
          sock.connect_nonblock(self)
        rescue IO::WaitWritable
          if !IO.select(nil, [sock], nil, timeout)
            raise Errno::ETIMEDOUT, 'user specified timeout'
          end
          begin
            sock.connect_nonblock(self) # check connection failure
          rescue Errno::EISCONN
          end
        end
      else
        sock.connect(self)
      end
    rescue Exception
      sock.close
      raise
    end
    if block_given?
      begin
        yield sock
      ensure
        sock.close if !sock.closed?
      end
    else
      sock
    end
  end
  private :connect_internal

  def connect_from(*args, &block)
    opts = Hash === args.last ? args.pop : {}
    local_addr_args = args
    connect_internal(family_addrinfo(*local_addr_args), opts[:timeout], &block)
  end

  def connect(opts={}, &block)
    connect_internal(nil, opts[:timeout], &block)
  end

  def connect_to(*args, &block)
    opts = Hash === args.last ? args.pop : {}
    remote_addr_args = args
    remote_addrinfo = family_addrinfo(*remote_addr_args)
    #nodyna <send-1893> <SD EASY (private methods)>
    remote_addrinfo.send(:connect_internal, self, opts[:timeout], &block)
  end

  def bind
    sock = Socket.new(self.pfamily, self.socktype, self.protocol)
    begin
      sock.ipv6only! if self.ipv6?
      sock.setsockopt(:SOCKET, :REUSEADDR, 1)
      sock.bind(self)
    rescue Exception
      sock.close
      raise
    end
    if block_given?
      begin
        yield sock
      ensure
        sock.close if !sock.closed?
      end
    else
      sock
    end
  end

  def listen(backlog=Socket::SOMAXCONN)
    sock = Socket.new(self.pfamily, self.socktype, self.protocol)
    begin
      sock.ipv6only! if self.ipv6?
      sock.setsockopt(:SOCKET, :REUSEADDR, 1)
      sock.bind(self)
      sock.listen(backlog)
    rescue Exception
      sock.close
      raise
    end
    if block_given?
      begin
        yield sock
      ensure
        sock.close if !sock.closed?
      end
    else
      sock
    end
  end

  def self.foreach(nodename, service, family=nil, socktype=nil, protocol=nil, flags=nil, &block)
    Addrinfo.getaddrinfo(nodename, service, family, socktype, protocol, flags).each(&block)
  end
end

class BasicSocket < IO
  def connect_address
    addr = local_address
    afamily = addr.afamily
    if afamily == Socket::AF_INET
      raise SocketError, "unbound IPv4 socket" if addr.ip_port == 0
      if addr.ip_address == "0.0.0.0"
        addr = Addrinfo.new(["AF_INET", addr.ip_port, nil, "127.0.0.1"], addr.pfamily, addr.socktype, addr.protocol)
      end
    elsif defined?(Socket::AF_INET6) && afamily == Socket::AF_INET6
      raise SocketError, "unbound IPv6 socket" if addr.ip_port == 0
      if addr.ip_address == "::"
        addr = Addrinfo.new(["AF_INET6", addr.ip_port, nil, "::1"], addr.pfamily, addr.socktype, addr.protocol)
      elsif addr.ip_address == "0.0.0.0" # MacOS X 10.4 returns "a.b.c.d" for IPv4-mapped IPv6 address.
        addr = Addrinfo.new(["AF_INET6", addr.ip_port, nil, "::1"], addr.pfamily, addr.socktype, addr.protocol)
      elsif addr.ip_address == "::ffff:0.0.0.0" # MacOS X 10.6 returns "::ffff:a.b.c.d" for IPv4-mapped IPv6 address.
        addr = Addrinfo.new(["AF_INET6", addr.ip_port, nil, "::1"], addr.pfamily, addr.socktype, addr.protocol)
      end
    elsif defined?(Socket::AF_UNIX) && afamily == Socket::AF_UNIX
      raise SocketError, "unbound Unix socket" if addr.unix_path == ""
    end
    addr
  end
end

class Socket < BasicSocket
  def ipv6only!
    if defined? Socket::IPV6_V6ONLY
      self.setsockopt(:IPV6, :V6ONLY, 1)
    end
  end

  def self.tcp(host, port, *rest) # :yield: socket
    opts = Hash === rest.last ? rest.pop : {}
    raise ArgumentError, "wrong number of arguments (#{rest.length} for 2)" if 2 < rest.length
    local_host, local_port = rest
    last_error = nil
    ret = nil

    connect_timeout = opts[:connect_timeout]

    local_addr_list = nil
    if local_host != nil || local_port != nil
      local_addr_list = Addrinfo.getaddrinfo(local_host, local_port, nil, :STREAM, nil)
    end

    Addrinfo.foreach(host, port, nil, :STREAM) {|ai|
      if local_addr_list
        local_addr = local_addr_list.find {|local_ai| local_ai.afamily == ai.afamily }
        next if !local_addr
      else
        local_addr = nil
      end
      begin
        sock = local_addr ?
          ai.connect_from(local_addr, :timeout => connect_timeout) :
          ai.connect(:timeout => connect_timeout)
      rescue SystemCallError
        last_error = $!
        next
      end
      ret = sock
      break
    }
    if !ret
      if last_error
        raise last_error
      else
        raise SocketError, "no appropriate local address"
      end
    end
    if block_given?
      begin
        yield ret
      ensure
        ret.close if !ret.closed?
      end
    else
      ret
    end
  end

  def self.ip_sockets_port0(ai_list, reuseaddr)
    sockets = []
    begin
      sockets.clear
      port = nil
      ai_list.each {|ai|
        begin
          s = Socket.new(ai.pfamily, ai.socktype, ai.protocol)
        rescue SystemCallError
          next
        end
        sockets << s
        s.ipv6only! if ai.ipv6?
        if reuseaddr
          s.setsockopt(:SOCKET, :REUSEADDR, 1)
        end
        if !port
          s.bind(ai)
          port = s.local_address.ip_port
        else
          s.bind(ai.family_addrinfo(ai.ip_address, port))
        end
      }
    rescue Errno::EADDRINUSE
      sockets.each {|s| s.close }
      retry
    rescue Exception
      sockets.each {|s| s.close }
      raise
    end
    sockets
  end
  class << self
    private :ip_sockets_port0
  end

  def self.tcp_server_sockets_port0(host)
    ai_list = Addrinfo.getaddrinfo(host, 0, nil, :STREAM, nil, Socket::AI_PASSIVE)
    sockets = ip_sockets_port0(ai_list, true)
    begin
      sockets.each {|s|
        s.listen(Socket::SOMAXCONN)
      }
    rescue Exception
      sockets.each {|s| s.close }
      raise
    end
    sockets
  end
  class << self
    private :tcp_server_sockets_port0
  end

  def self.tcp_server_sockets(host=nil, port)
    if port == 0
      sockets = tcp_server_sockets_port0(host)
    else
      last_error = nil
      sockets = []
      begin
        Addrinfo.foreach(host, port, nil, :STREAM, nil, Socket::AI_PASSIVE) {|ai|
          begin
            s = ai.listen
          rescue SystemCallError
            last_error = $!
            next
          end
          sockets << s
        }
        if sockets.empty?
          raise last_error
        end
      rescue Exception
        sockets.each {|s| s.close }
        raise
      end
    end
    if block_given?
      begin
        yield sockets
      ensure
        sockets.each {|s| s.close if !s.closed? }
      end
    else
      sockets
    end
  end

  def self.accept_loop(*sockets) # :yield: socket, client_addrinfo
    sockets.flatten!(1)
    if sockets.empty?
      raise ArgumentError, "no sockets"
    end
    loop {
      readable, _, _ = IO.select(sockets)
      readable.each {|r|
        begin
          sock, addr = r.accept_nonblock
        rescue IO::WaitReadable
          next
        end
        yield sock, addr
      }
    }
  end

  def self.tcp_server_loop(host=nil, port, &b) # :yield: socket, client_addrinfo
    tcp_server_sockets(host, port) {|sockets|
      accept_loop(sockets, &b)
    }
  end

  def self.udp_server_sockets(host=nil, port)
    last_error = nil
    sockets = []

    ipv6_recvpktinfo = nil
    if defined? Socket::AncillaryData
      if defined? Socket::IPV6_RECVPKTINFO # RFC 3542
        ipv6_recvpktinfo = Socket::IPV6_RECVPKTINFO
      elsif defined? Socket::IPV6_PKTINFO # RFC 2292
        ipv6_recvpktinfo = Socket::IPV6_PKTINFO
      end
    end

    local_addrs = Socket.ip_address_list

    ip_list = []
    Addrinfo.foreach(host, port, nil, :DGRAM, nil, Socket::AI_PASSIVE) {|ai|
      if ai.ipv4? && ai.ip_address == "0.0.0.0"
        local_addrs.each {|a|
          next if !a.ipv4?
          ip_list << Addrinfo.new(a.to_sockaddr, :INET, :DGRAM, 0);
        }
      elsif ai.ipv6? && ai.ip_address == "::" && !ipv6_recvpktinfo
        local_addrs.each {|a|
          next if !a.ipv6?
          ip_list << Addrinfo.new(a.to_sockaddr, :INET6, :DGRAM, 0);
        }
      else
        ip_list << ai
      end
    }

    if port == 0
      sockets = ip_sockets_port0(ip_list, false)
    else
      ip_list.each {|ip|
        ai = Addrinfo.udp(ip.ip_address, port)
        begin
          s = ai.bind
        rescue SystemCallError
          last_error = $!
          next
        end
        sockets << s
      }
      if sockets.empty?
        raise last_error
      end
    end

    sockets.each {|s|
      ai = s.local_address
      if ipv6_recvpktinfo && ai.ipv6? && ai.ip_address == "::"
        s.setsockopt(:IPV6, ipv6_recvpktinfo, 1)
      end
    }

    if block_given?
      begin
        yield sockets
      ensure
        sockets.each {|s| s.close if !s.closed? } if sockets
      end
    else
      sockets
    end
  end

  def self.udp_server_recv(sockets)
    sockets.each {|r|
      begin
        msg, sender_addrinfo, _, *controls = r.recvmsg_nonblock
      rescue IO::WaitReadable
        next
      end
      ai = r.local_address
      if ai.ipv6? and pktinfo = controls.find {|c| c.cmsg_is?(:IPV6, :PKTINFO) }
        ai = Addrinfo.udp(pktinfo.ipv6_pktinfo_addr.ip_address, ai.ip_port)
        yield msg, UDPSource.new(sender_addrinfo, ai) {|reply_msg|
          r.sendmsg reply_msg, 0, sender_addrinfo, pktinfo
        }
      else
        yield msg, UDPSource.new(sender_addrinfo, ai) {|reply_msg|
          #nodyna <send-1894> <SD COMPLEX (change-prone variables)>
          r.send reply_msg, 0, sender_addrinfo
        }
      end
    }
  end

  def self.udp_server_loop_on(sockets, &b) # :yield: msg, msg_src
    loop {
      readable, _, _ = IO.select(sockets)
      udp_server_recv(readable, &b)
    }
  end

  def self.udp_server_loop(host=nil, port, &b) # :yield: message, message_source
    udp_server_sockets(host, port) {|sockets|
      udp_server_loop_on(sockets, &b)
    }
  end

  class UDPSource
    def initialize(remote_address, local_address, &reply_proc)
      @remote_address = remote_address
      @local_address = local_address
      @reply_proc = reply_proc
    end

    attr_reader :remote_address

    attr_reader :local_address

    def inspect # :nodoc:
      "\#<#{self.class}: #{@remote_address.inspect_sockaddr} to #{@local_address.inspect_sockaddr}>"
    end

    def reply(msg)
      @reply_proc.call msg
    end
  end

  def self.unix(path) # :yield: socket
    addr = Addrinfo.unix(path)
    sock = addr.connect
    if block_given?
      begin
        yield sock
      ensure
        sock.close if !sock.closed?
      end
    else
      sock
    end
  end

  def self.unix_server_socket(path)
    if !unix_socket_abstract_name?(path)
      begin
        st = File.lstat(path)
      rescue Errno::ENOENT
      end
      if st && st.socket? && st.owned?
        File.unlink path
      end
    end
    s = Addrinfo.unix(path).listen
    if block_given?
      begin
        yield s
      ensure
        s.close if !s.closed?
        if !unix_socket_abstract_name?(path)
          File.unlink path
        end
      end
    else
      s
    end
  end

  class << self
    private

    def unix_socket_abstract_name?(path)
      /linux/ =~ RUBY_PLATFORM && /\A(\0|\z)/ =~ path
    end
  end

  def self.unix_server_loop(path, &b) # :yield: socket, client_addrinfo
    unix_server_socket(path) {|serv|
      accept_loop(serv, &b)
    }
  end

end

