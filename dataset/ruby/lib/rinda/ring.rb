require 'drb/drb'
require 'rinda/rinda'
require 'thread'
require 'ipaddr'

module Rinda


  Ring_PORT = 7647


  class RingServer

    include DRbUndumped


    class Renewer # :nodoc:
      include DRbUndumped


      attr_writer :renew

      def initialize # :nodoc:
        @renew = true
      end

      def renew # :nodoc:
        @renew ? 1 : true
      end
    end


    def initialize(ts, addresses=[Socket::INADDR_ANY], port=Ring_PORT)
      @port = port

      if Integer === addresses then
        addresses, @port = [Socket::INADDR_ANY], addresses
      end

      @renewer = Renewer.new

      @ts = ts
      @sockets = []
      addresses.each do |address|
        if Array === address
          make_socket(*address)
        else
          make_socket(address)
        end
      end

      @w_services = write_services
      @r_service  = reply_service
    end


    def make_socket(address, interface_address=nil, multicast_interface=0)
      addrinfo = Addrinfo.udp(address, @port)

      socket = Socket.new(addrinfo.pfamily, addrinfo.socktype,
                          addrinfo.protocol)
      @sockets << socket

      if addrinfo.ipv4_multicast? or addrinfo.ipv6_multicast? then
        if Socket.const_defined?(:SO_REUSEPORT) then
          socket.setsockopt(:SOCKET, :SO_REUSEPORT, true)
        else
          socket.setsockopt(:SOCKET, :SO_REUSEADDR, true)
        end

        if addrinfo.ipv4_multicast? then
          interface_address = '0.0.0.0' if interface_address.nil?
          socket.bind(Addrinfo.udp(interface_address, @port))

          mreq = IPAddr.new(addrinfo.ip_address).hton +
            IPAddr.new(interface_address).hton

          socket.setsockopt(:IPPROTO_IP, :IP_ADD_MEMBERSHIP, mreq)
        else
          interface_address = '::1' if interface_address.nil?
          socket.bind(Addrinfo.udp(interface_address, @port))

          mreq = IPAddr.new(addrinfo.ip_address).hton +
            [multicast_interface].pack('I')

          socket.setsockopt(:IPPROTO_IPV6, :IPV6_JOIN_GROUP, mreq)
        end
      else
        socket.bind(addrinfo)
      end

      socket
    end


    def write_services
      @sockets.map do |s|
        Thread.new(s) do |socket|
          loop do
            msg = socket.recv(1024)
            do_write(msg)
          end
        end
      end
    end


    def do_write(msg)
      Thread.new do
        begin
          tuple, sec = Marshal.load(msg)
          @ts.write(tuple, sec)
        rescue
        end
      end
    end


    def reply_service
      Thread.new do
        loop do
          do_reply
        end
      end
    end


    def do_reply
      tuple = @ts.take([:lookup_ring, nil], @renewer)
      Thread.new { tuple[1].call(@ts) rescue nil}
    rescue
    end


    def shutdown
      @renewer.renew = false

      @w_services.each do |thread|
        thread.kill
        thread.join
      end

      @sockets.each do |socket|
        socket.close
      end

      @r_service.kill
      @r_service.join
    end

  end


  class RingFinger

    @@broadcast_list = ['<broadcast>', 'localhost']

    @@finger = nil


    def self.finger
      unless @@finger
        @@finger = self.new
        @@finger.lookup_ring_any
      end
      @@finger
    end


    def self.primary
      finger.primary
    end


    def self.to_a
      finger.to_a
    end


    attr_accessor :broadcast_list


    attr_accessor :multicast_hops


    attr_accessor :multicast_interface


    attr_accessor :port


    attr_accessor :primary


    def initialize(broadcast_list=@@broadcast_list, port=Ring_PORT)
      @broadcast_list = broadcast_list || ['localhost']
      @port = port
      @primary = nil
      @rings = []

      @multicast_hops = 1
      @multicast_interface = 0
    end


    def to_a
      @rings
    end


    def each
      lookup_ring_any unless @primary
      return unless @primary
      yield(@primary)
      @rings.each { |x| yield(x) }
    end


    def lookup_ring(timeout=5, &block)
      return lookup_ring_any(timeout) unless block_given?

      msg = Marshal.dump([[:lookup_ring, DRbObject.new(block)], timeout])
      @broadcast_list.each do |it|
        send_message(it, msg)
      end
      sleep(timeout)
    end


    def lookup_ring_any(timeout=5)
      queue = Queue.new

      Thread.new do
        self.lookup_ring(timeout) do |ts|
          queue.push(ts)
        end
        queue.push(nil)
      end

      @primary = queue.pop
      raise('RingNotFound') if @primary.nil?

      Thread.new do
        while it = queue.pop
          @rings.push(it)
        end
      end

      @primary
    end


    def make_socket(address) # :nodoc:
      addrinfo = Addrinfo.udp(address, @port)

      soc = Socket.new(addrinfo.pfamily, addrinfo.socktype, addrinfo.protocol)
      begin
        if addrinfo.ipv4_multicast? then
          soc.setsockopt(Socket::Option.ipv4_multicast_loop(1))
          soc.setsockopt(Socket::Option.ipv4_multicast_ttl(@multicast_hops))
        elsif addrinfo.ipv6_multicast? then
          soc.setsockopt(:IPPROTO_IPV6, :IPV6_MULTICAST_LOOP, true)
          soc.setsockopt(:IPPROTO_IPV6, :IPV6_MULTICAST_HOPS,
                         [@multicast_hops].pack('I'))
          soc.setsockopt(:IPPROTO_IPV6, :IPV6_MULTICAST_IF,
                         [@multicast_interface].pack('I'))
        else
          soc.setsockopt(:SOL_SOCKET, :SO_BROADCAST, true)
        end

        soc.connect(addrinfo)
      rescue Exception
        soc.close
        raise
      end

      soc
    end

    def send_message(address, message) # :nodoc:
      soc = make_socket(address)

      #nodyna <send-2232> <SD COMPLEX (change-prone variables)>
      soc.send(message, 0)
    rescue
      nil
    ensure
      soc.close if soc
    end

  end


  class RingProvider


    def initialize(klass, front, desc, renewer = nil)
      @tuple = [:name, klass, front, desc]
      @renewer = renewer || Rinda::SimpleRenewer.new
    end


    def provide
      ts = Rinda::RingFinger.primary
      ts.write(@tuple, @renewer)
    end

  end

end
