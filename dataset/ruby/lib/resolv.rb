require 'socket'
require 'timeout'
require 'thread'

begin
  require 'securerandom'
rescue LoadError
end


class Resolv


  def self.getaddress(name)
    DefaultResolver.getaddress(name)
  end


  def self.getaddresses(name)
    DefaultResolver.getaddresses(name)
  end


  def self.each_address(name, &block)
    DefaultResolver.each_address(name, &block)
  end


  def self.getname(address)
    DefaultResolver.getname(address)
  end


  def self.getnames(address)
    DefaultResolver.getnames(address)
  end


  def self.each_name(address, &proc)
    DefaultResolver.each_name(address, &proc)
  end


  def initialize(resolvers=[Hosts.new, DNS.new])
    @resolvers = resolvers
  end


  def getaddress(name)
    each_address(name) {|address| return address}
    raise ResolvError.new("no address for #{name}")
  end


  def getaddresses(name)
    ret = []
    each_address(name) {|address| ret << address}
    return ret
  end


  def each_address(name)
    if AddressRegex =~ name
      yield name
      return
    end
    yielded = false
    @resolvers.each {|r|
      r.each_address(name) {|address|
        yield address.to_s
        yielded = true
      }
      return if yielded
    }
  end


  def getname(address)
    each_name(address) {|name| return name}
    raise ResolvError.new("no name for #{address}")
  end


  def getnames(address)
    ret = []
    each_name(address) {|name| ret << name}
    return ret
  end


  def each_name(address)
    yielded = false
    @resolvers.each {|r|
      r.each_name(address) {|name|
        yield name.to_s
        yielded = true
      }
      return if yielded
    }
  end


  class ResolvError < StandardError; end


  class ResolvTimeout < Timeout::Error; end


  class Hosts
    begin
      raise LoadError unless /mswin|mingw|cygwin/ =~ RUBY_PLATFORM
      require 'win32/resolv'
      DefaultFileName = Win32::Resolv.get_hosts_path
    rescue LoadError
      DefaultFileName = '/etc/hosts'
    end


    def initialize(filename = DefaultFileName)
      @filename = filename
      @mutex = Mutex.new
      @initialized = nil
    end

    def lazy_initialize # :nodoc:
      @mutex.synchronize {
        unless @initialized
          @name2addr = {}
          @addr2name = {}
          open(@filename, 'rb') {|f|
            f.each {|line|
              line.sub!(/#.*/, '')
              addr, hostname, *aliases = line.split(/\s+/)
              next unless addr
              addr.untaint
              hostname.untaint
              @addr2name[addr] = [] unless @addr2name.include? addr
              @addr2name[addr] << hostname
              @addr2name[addr] += aliases
              @name2addr[hostname] = [] unless @name2addr.include? hostname
              @name2addr[hostname] << addr
              aliases.each {|n|
                n.untaint
                @name2addr[n] = [] unless @name2addr.include? n
                @name2addr[n] << addr
              }
            }
          }
          @name2addr.each {|name, arr| arr.reverse!}
          @initialized = true
        end
      }
      self
    end


    def getaddress(name)
      each_address(name) {|address| return address}
      raise ResolvError.new("#{@filename} has no name: #{name}")
    end


    def getaddresses(name)
      ret = []
      each_address(name) {|address| ret << address}
      return ret
    end


    def each_address(name, &proc)
      lazy_initialize
      if @name2addr.include?(name)
        @name2addr[name].each(&proc)
      end
    end


    def getname(address)
      each_name(address) {|name| return name}
      raise ResolvError.new("#{@filename} has no address: #{address}")
    end


    def getnames(address)
      ret = []
      each_name(address) {|name| ret << name}
      return ret
    end


    def each_name(address, &proc)
      lazy_initialize
      if @addr2name.include?(address)
        @addr2name[address].each(&proc)
      end
    end
  end


  class DNS


    Port = 53


    UDPSize = 512


    def self.open(*args)
      dns = new(*args)
      return dns unless block_given?
      begin
        yield dns
      ensure
        dns.close
      end
    end


    def initialize(config_info=nil)
      @mutex = Mutex.new
      @config = Config.new(config_info)
      @initialized = nil
    end

    def timeouts=(values)
      @config.timeouts = values
    end

    def lazy_initialize # :nodoc:
      @mutex.synchronize {
        unless @initialized
          @config.lazy_initialize
          @initialized = true
        end
      }
      self
    end


    def close
      @mutex.synchronize {
        if @initialized
          @initialized = false
        end
      }
    end


    def getaddress(name)
      each_address(name) {|address| return address}
      raise ResolvError.new("DNS result has no information for #{name}")
    end


    def getaddresses(name)
      ret = []
      each_address(name) {|address| ret << address}
      return ret
    end


    def each_address(name)
      each_resource(name, Resource::IN::A) {|resource| yield resource.address}
      if use_ipv6?
        each_resource(name, Resource::IN::AAAA) {|resource| yield resource.address}
      end
    end

    def use_ipv6? # :nodoc:
      begin
        list = Socket.ip_address_list
      rescue NotImplementedError
        return true
      end
      list.any? {|a| a.ipv6? && !a.ipv6_loopback? && !a.ipv6_linklocal? }
    end
    private :use_ipv6?


    def getname(address)
      each_name(address) {|name| return name}
      raise ResolvError.new("DNS result has no information for #{address}")
    end


    def getnames(address)
      ret = []
      each_name(address) {|name| ret << name}
      return ret
    end


    def each_name(address)
      case address
      when Name
        ptr = address
      when IPv4::Regex
        ptr = IPv4.create(address).to_name
      when IPv6::Regex
        ptr = IPv6.create(address).to_name
      else
        raise ResolvError.new("cannot interpret as address: #{address}")
      end
      each_resource(ptr, Resource::IN::PTR) {|resource| yield resource.name}
    end


    def getresource(name, typeclass)
      each_resource(name, typeclass) {|resource| return resource}
      raise ResolvError.new("DNS result has no information for #{name}")
    end


    def getresources(name, typeclass)
      ret = []
      each_resource(name, typeclass) {|resource| ret << resource}
      return ret
    end


    def each_resource(name, typeclass, &proc)
      fetch_resource(name, typeclass) {|reply, reply_name|
        extract_resources(reply, reply_name, typeclass, &proc)
      }
    end

    def fetch_resource(name, typeclass)
      lazy_initialize
      requester = make_udp_requester
      senders = {}
      begin
        @config.resolv(name) {|candidate, tout, nameserver, port|
          msg = Message.new
          msg.rd = 1
          msg.add_question(candidate, typeclass)
          unless sender = senders[[candidate, nameserver, port]]
            sender = requester.sender(msg, candidate, nameserver, port)
            next if !sender
            senders[[candidate, nameserver, port]] = sender
          end
          reply, reply_name = requester.request(sender, tout)
          case reply.rcode
          when RCode::NoError
            if reply.tc == 1 and not Requester::TCP === requester
              requester.close
              requester = make_tcp_requester(nameserver, port)
              senders = {}
              redo
            else
              yield(reply, reply_name)
            end
            return
          when RCode::NXDomain
            raise Config::NXDomain.new(reply_name.to_s)
          else
            raise Config::OtherResolvError.new(reply_name.to_s)
          end
        }
      ensure
        requester.close
      end
    end

    def make_udp_requester # :nodoc:
      nameserver_port = @config.nameserver_port
      if nameserver_port.length == 1
        Requester::ConnectedUDP.new(*nameserver_port[0])
      else
        Requester::UnconnectedUDP.new(*nameserver_port)
      end
    end

    def make_tcp_requester(host, port) # :nodoc:
      return Requester::TCP.new(host, port)
    end

    def extract_resources(msg, name, typeclass) # :nodoc:
      if typeclass < Resource::ANY
        n0 = Name.create(name)
        msg.each_answer {|n, ttl, data|
          yield data if n0 == n
        }
      end
      yielded = false
      n0 = Name.create(name)
      msg.each_answer {|n, ttl, data|
        if n0 == n
          case data
          when typeclass
            yield data
            yielded = true
          when Resource::CNAME
            n0 = data.name
          end
        end
      }
      return if yielded
      msg.each_answer {|n, ttl, data|
        if n0 == n
          case data
          when typeclass
            yield data
          end
        end
      }
    end

    if defined? SecureRandom
      def self.random(arg) # :nodoc:
        begin
          SecureRandom.random_number(arg)
        rescue NotImplementedError
          rand(arg)
        end
      end
    else
      def self.random(arg) # :nodoc:
        rand(arg)
      end
    end


    def self.rangerand(range) # :nodoc:
      base = range.begin
      len = range.end - range.begin
      if !range.exclude_end?
        len += 1
      end
      base + random(len)
    end

    RequestID = {} # :nodoc:
    RequestIDMutex = Mutex.new # :nodoc:

    def self.allocate_request_id(host, port) # :nodoc:
      id = nil
      RequestIDMutex.synchronize {
        h = (RequestID[[host, port]] ||= {})
        begin
          id = rangerand(0x0000..0xffff)
        end while h[id]
        h[id] = true
      }
      id
    end

    def self.free_request_id(host, port, id) # :nodoc:
      RequestIDMutex.synchronize {
        key = [host, port]
        if h = RequestID[key]
          h.delete id
          if h.empty?
            RequestID.delete key
          end
        end
      }
    end

    def self.bind_random_port(udpsock, bind_host="0.0.0.0") # :nodoc:
      begin
        port = rangerand(1024..65535)
        udpsock.bind(bind_host, port)
      rescue Errno::EADDRINUSE, # POSIX
             Errno::EACCES, # SunOS: See PRIV_SYS_NFS in privileges(5)
             Errno::EPERM # FreeBSD: security.mac.portacl.port_high is configurable.  See mac_portacl(4).
        retry
      end
    end

    class Requester # :nodoc:
      def initialize
        @senders = {}
        @socks = nil
      end

      def request(sender, tout)
        start = Time.now
        timelimit = start + tout
        begin
          #nodyna <send-1895> <not yet classified>
          sender.send
        rescue Errno::EHOSTUNREACH, # multi-homed IPv6 may generate this
               Errno::ENETUNREACH
          raise ResolvTimeout
        end
        while true
          before_select = Time.now
          timeout = timelimit - before_select
          if timeout <= 0
            raise ResolvTimeout
          end
          select_result = IO.select(@socks, nil, nil, timeout)
          if !select_result
            after_select = Time.now
            next if after_select < timelimit
            raise ResolvTimeout
          end
          begin
            reply, from = recv_reply(select_result[0])
          rescue Errno::ECONNREFUSED, # GNU/Linux, FreeBSD
                 Errno::ECONNRESET # Windows
            raise ResolvTimeout
          end
          begin
            msg = Message.decode(reply)
          rescue DecodeError
            next # broken DNS message ignored
          end
          if s = sender_for(from, msg)
            break
          else
          end
        end
        return msg, s.data
      end

      def sender_for(addr, msg)
        @senders[[addr,msg.id]]
      end

      def close
        socks = @socks
        @socks = nil
        if socks
          socks.each {|sock| sock.close }
        end
      end

      class Sender # :nodoc:
        def initialize(msg, data, sock)
          @msg = msg
          @data = data
          @sock = sock
        end
      end

      class UnconnectedUDP < Requester # :nodoc:
        def initialize(*nameserver_port)
          super()
          @nameserver_port = nameserver_port
          @socks_hash = {}
          @socks = []
          nameserver_port.each {|host, port|
            if host.index(':')
              bind_host = "::"
              af = Socket::AF_INET6
            else
              bind_host = "0.0.0.0"
              af = Socket::AF_INET
            end
            next if @socks_hash[bind_host]
            begin
              sock = UDPSocket.new(af)
            rescue Errno::EAFNOSUPPORT
              next # The kernel doesn't support the address family.
            end
            sock.do_not_reverse_lookup = true
            DNS.bind_random_port(sock, bind_host)
            @socks << sock
            @socks_hash[bind_host] = sock
          }
        end

        def recv_reply(readable_socks)
          reply, from = readable_socks[0].recvfrom(UDPSize)
          return reply, [from[3],from[1]]
        end

        def sender(msg, data, host, port=Port)
          sock = @socks_hash[host.index(':') ? "::" : "0.0.0.0"]
          return nil if !sock
          service = [host, port]
          id = DNS.allocate_request_id(host, port)
          request = msg.encode
          request[0,2] = [id].pack('n')
          return @senders[[service, id]] =
            Sender.new(request, data, sock, host, port)
        end

        def close
          super
          @senders.each_key {|service, id|
            DNS.free_request_id(service[0], service[1], id)
          }
        end

        class Sender < Requester::Sender # :nodoc:
          def initialize(msg, data, sock, host, port)
            super(msg, data, sock)
            @host = host
            @port = port
          end
          attr_reader :data

          #nodyna <send-1896> <not yet classified>
          def send
            raise "@sock is nil." if @sock.nil?
            #nodyna <send-1897> <SD COMPLEX (change-prone variables)>
            @sock.send(@msg, 0, @host, @port)
          end
        end
      end

      class ConnectedUDP < Requester # :nodoc:
        def initialize(host, port=Port)
          super()
          @host = host
          @port = port
          is_ipv6 = host.index(':')
          sock = UDPSocket.new(is_ipv6 ? Socket::AF_INET6 : Socket::AF_INET)
          @socks = [sock]
          sock.do_not_reverse_lookup = true
          DNS.bind_random_port(sock, is_ipv6 ? "::" : "0.0.0.0")
          sock.connect(host, port)
        end

        def recv_reply(readable_socks)
          reply = readable_socks[0].recv(UDPSize)
          return reply, nil
        end

        def sender(msg, data, host=@host, port=@port)
          unless host == @host && port == @port
            raise RequestError.new("host/port don't match: #{host}:#{port}")
          end
          id = DNS.allocate_request_id(@host, @port)
          request = msg.encode
          request[0,2] = [id].pack('n')
          return @senders[[nil,id]] = Sender.new(request, data, @socks[0])
        end

        def close
          super
          @senders.each_key {|from, id|
            DNS.free_request_id(@host, @port, id)
          }
        end

        class Sender < Requester::Sender # :nodoc:
          #nodyna <send-1898> <not yet classified>
          def send
            raise "@sock is nil." if @sock.nil?
            #nodyna <send-1899> <SD COMPLEX (change-prone variables)>
            @sock.send(@msg, 0)
          end
          attr_reader :data
        end
      end

      class MDNSOneShot < UnconnectedUDP # :nodoc:
        def sender(msg, data, host, port=Port)
          id = DNS.allocate_request_id(host, port)
          request = msg.encode
          request[0,2] = [id].pack('n')
          sock = @socks_hash[host.index(':') ? "::" : "0.0.0.0"]
          return @senders[id] =
            UnconnectedUDP::Sender.new(request, data, sock, host, port)
        end

        def sender_for(addr, msg)
          @senders[msg.id]
        end
      end

      class TCP < Requester # :nodoc:
        def initialize(host, port=Port)
          super()
          @host = host
          @port = port
          sock = TCPSocket.new(@host, @port)
          @socks = [sock]
          @senders = {}
        end

        def recv_reply(readable_socks)
          len = readable_socks[0].read(2).unpack('n')[0]
          reply = @socks[0].read(len)
          return reply, nil
        end

        def sender(msg, data, host=@host, port=@port)
          unless host == @host && port == @port
            raise RequestError.new("host/port don't match: #{host}:#{port}")
          end
          id = DNS.allocate_request_id(@host, @port)
          request = msg.encode
          request[0,2] = [request.length, id].pack('nn')
          return @senders[[nil,id]] = Sender.new(request, data, @socks[0])
        end

        class Sender < Requester::Sender # :nodoc:
          #nodyna <send-1900> <not yet classified>
          def send
            @sock.print(@msg)
            @sock.flush
          end
          attr_reader :data
        end

        def close
          super
          @senders.each_key {|from,id|
            DNS.free_request_id(@host, @port, id)
          }
        end
      end


      class RequestError < StandardError
      end
    end

    class Config # :nodoc:
      def initialize(config_info=nil)
        @mutex = Mutex.new
        @config_info = config_info
        @initialized = nil
        @timeouts = nil
      end

      def timeouts=(values)
        if values
          values = Array(values)
          values.each do |t|
            Numeric === t or raise ArgumentError, "#{t.inspect} is not numeric"
            t > 0.0 or raise ArgumentError, "timeout=#{t} must be positive"
          end
          @timeouts = values
        else
          @timeouts = nil
        end
      end

      def Config.parse_resolv_conf(filename)
        nameserver = []
        search = nil
        ndots = 1
        open(filename, 'rb') {|f|
          f.each {|line|
            line.sub!(/[#;].*/, '')
            keyword, *args = line.split(/\s+/)
            args.each { |arg|
              arg.untaint
            }
            next unless keyword
            case keyword
            when 'nameserver'
              nameserver += args
            when 'domain'
              next if args.empty?
              search = [args[0]]
            when 'search'
              next if args.empty?
              search = args
            when 'options'
              args.each {|arg|
                case arg
                when /\Andots:(\d+)\z/
                  ndots = $1.to_i
                end
              }
            end
          }
        }
        return { :nameserver => nameserver, :search => search, :ndots => ndots }
      end

      def Config.default_config_hash(filename="/etc/resolv.conf")
        if File.exist? filename
          config_hash = Config.parse_resolv_conf(filename)
        else
          if /mswin|cygwin|mingw|bccwin/ =~ RUBY_PLATFORM
            require 'win32/resolv'
            search, nameserver = Win32::Resolv.get_resolv_info
            config_hash = {}
            config_hash[:nameserver] = nameserver if nameserver
            config_hash[:search] = [search].flatten if search
          end
        end
        config_hash || {}
      end

      def lazy_initialize
        @mutex.synchronize {
          unless @initialized
            @nameserver_port = []
            @search = nil
            @ndots = 1
            case @config_info
            when nil
              config_hash = Config.default_config_hash
            when String
              config_hash = Config.parse_resolv_conf(@config_info)
            when Hash
              config_hash = @config_info.dup
              if String === config_hash[:nameserver]
                config_hash[:nameserver] = [config_hash[:nameserver]]
              end
              if String === config_hash[:search]
                config_hash[:search] = [config_hash[:search]]
              end
            else
              raise ArgumentError.new("invalid resolv configuration: #{@config_info.inspect}")
            end
            if config_hash.include? :nameserver
              @nameserver_port = config_hash[:nameserver].map {|ns| [ns, Port] }
            end
            if config_hash.include? :nameserver_port
              @nameserver_port = config_hash[:nameserver_port].map {|ns, port| [ns, (port || Port)] }
            end
            @search = config_hash[:search] if config_hash.include? :search
            @ndots = config_hash[:ndots] if config_hash.include? :ndots

            if @nameserver_port.empty?
              @nameserver_port << ['0.0.0.0', Port]
            end
            if @search
              @search = @search.map {|arg| Label.split(arg) }
            else
              hostname = Socket.gethostname
              if /\./ =~ hostname
                @search = [Label.split($')]
              else
                @search = [[]]
              end
            end

            if !@nameserver_port.kind_of?(Array) ||
               @nameserver_port.any? {|ns_port|
                  !(Array === ns_port) ||
                  ns_port.length != 2
                  !(String === ns_port[0]) ||
                  !(Integer === ns_port[1])
               }
              raise ArgumentError.new("invalid nameserver config: #{@nameserver_port.inspect}")
            end

            if !@search.kind_of?(Array) ||
               !@search.all? {|ls| ls.all? {|l| Label::Str === l } }
              raise ArgumentError.new("invalid search config: #{@search.inspect}")
            end

            if !@ndots.kind_of?(Integer)
              raise ArgumentError.new("invalid ndots config: #{@ndots.inspect}")
            end

            @initialized = true
          end
        }
        self
      end

      def single?
        lazy_initialize
        if @nameserver_port.length == 1
          return @nameserver_port[0]
        else
          return nil
        end
      end

      def nameserver_port
        @nameserver_port
      end

      def generate_candidates(name)
        candidates = nil
        name = Name.create(name)
        if name.absolute?
          candidates = [name]
        else
          if @ndots <= name.length - 1
            candidates = [Name.new(name.to_a)]
          else
            candidates = []
          end
          candidates.concat(@search.map {|domain| Name.new(name.to_a + domain)})
          fname = Name.create("#{name}.")
          if !candidates.include?(fname)
            candidates << fname
          end
        end
        return candidates
      end

      InitialTimeout = 5

      def generate_timeouts
        ts = [InitialTimeout]
        ts << ts[-1] * 2 / @nameserver_port.length
        ts << ts[-1] * 2
        ts << ts[-1] * 2
        return ts
      end

      def resolv(name)
        candidates = generate_candidates(name)
        timeouts = @timeouts || generate_timeouts
        begin
          candidates.each {|candidate|
            begin
              timeouts.each {|tout|
                @nameserver_port.each {|nameserver, port|
                  begin
                    yield candidate, tout, nameserver, port
                  rescue ResolvTimeout
                  end
                }
              }
              raise ResolvError.new("DNS resolv timeout: #{name}")
            rescue NXDomain
            end
          }
        rescue ResolvError
        end
      end


      class NXDomain < ResolvError
      end


      class OtherResolvError < ResolvError
      end
    end

    module OpCode # :nodoc:
      Query = 0
      IQuery = 1
      Status = 2
      Notify = 4
      Update = 5
    end

    module RCode # :nodoc:
      NoError = 0
      FormErr = 1
      ServFail = 2
      NXDomain = 3
      NotImp = 4
      Refused = 5
      YXDomain = 6
      YXRRSet = 7
      NXRRSet = 8
      NotAuth = 9
      NotZone = 10
      BADVERS = 16
      BADSIG = 16
      BADKEY = 17
      BADTIME = 18
      BADMODE = 19
      BADNAME = 20
      BADALG = 21
    end


    class DecodeError < StandardError
    end


    class EncodeError < StandardError
    end

    module Label # :nodoc:
      def self.split(arg)
        labels = []
        arg.scan(/[^\.]+/) {labels << Str.new($&)}
        return labels
      end

      class Str # :nodoc:
        def initialize(string)
          @string = string
          @downcase = string.downcase
        end
        attr_reader :string, :downcase

        def to_s
          return @string
        end

        def inspect
          return "#<#{self.class} #{self}>"
        end

        def ==(other)
          return self.class == other.class && @downcase == other.downcase
        end

        def eql?(other)
          return self == other
        end

        def hash
          return @downcase.hash
        end
      end
    end


    class Name


      def self.create(arg)
        case arg
        when Name
          return arg
        when String
          return Name.new(Label.split(arg), /\.\z/ =~ arg ? true : false)
        else
          raise ArgumentError.new("cannot interpret as DNS name: #{arg.inspect}")
        end
      end

      def initialize(labels, absolute=true) # :nodoc:
        labels = labels.map {|label|
          case label
          when String then Label::Str.new(label)
          when Label::Str then label
          else
            raise ArgumentError, "unexpected label: #{label.inspect}"
          end
        }
        @labels = labels
        @absolute = absolute
      end

      def inspect # :nodoc:
        "#<#{self.class}: #{self}#{@absolute ? '.' : ''}>"
      end


      def absolute?
        return @absolute
      end

      def ==(other) # :nodoc:
        return false unless Name === other
        return false unless @absolute == other.absolute?
        return @labels == other.to_a
      end

      alias eql? == # :nodoc:


      def subdomain_of?(other)
        raise ArgumentError, "not a domain name: #{other.inspect}" unless Name === other
        return false if @absolute != other.absolute?
        other_len = other.length
        return false if @labels.length <= other_len
        return @labels[-other_len, other_len] == other.to_a
      end

      def hash # :nodoc:
        return @labels.hash ^ @absolute.hash
      end

      def to_a # :nodoc:
        return @labels
      end

      def length # :nodoc:
        return @labels.length
      end

      def [](i) # :nodoc:
        return @labels[i]
      end


      def to_s
        return @labels.join('.')
      end
    end

    class Message # :nodoc:
      @@identifier = -1

      def initialize(id = (@@identifier += 1) & 0xffff)
        @id = id
        @qr = 0
        @opcode = 0
        @aa = 0
        @tc = 0
        @rd = 0 # recursion desired
        @ra = 0 # recursion available
        @rcode = 0
        @question = []
        @answer = []
        @authority = []
        @additional = []
      end

      attr_accessor :id, :qr, :opcode, :aa, :tc, :rd, :ra, :rcode
      attr_reader :question, :answer, :authority, :additional

      def ==(other)
        return @id == other.id &&
               @qr == other.qr &&
               @opcode == other.opcode &&
               @aa == other.aa &&
               @tc == other.tc &&
               @rd == other.rd &&
               @ra == other.ra &&
               @rcode == other.rcode &&
               @question == other.question &&
               @answer == other.answer &&
               @authority == other.authority &&
               @additional == other.additional
      end

      def add_question(name, typeclass)
        @question << [Name.create(name), typeclass]
      end

      def each_question
        @question.each {|name, typeclass|
          yield name, typeclass
        }
      end

      def add_answer(name, ttl, data)
        @answer << [Name.create(name), ttl, data]
      end

      def each_answer
        @answer.each {|name, ttl, data|
          yield name, ttl, data
        }
      end

      def add_authority(name, ttl, data)
        @authority << [Name.create(name), ttl, data]
      end

      def each_authority
        @authority.each {|name, ttl, data|
          yield name, ttl, data
        }
      end

      def add_additional(name, ttl, data)
        @additional << [Name.create(name), ttl, data]
      end

      def each_additional
        @additional.each {|name, ttl, data|
          yield name, ttl, data
        }
      end

      def each_resource
        each_answer {|name, ttl, data| yield name, ttl, data}
        each_authority {|name, ttl, data| yield name, ttl, data}
        each_additional {|name, ttl, data| yield name, ttl, data}
      end

      def encode
        return MessageEncoder.new {|msg|
          msg.put_pack('nnnnnn',
            @id,
            (@qr & 1) << 15 |
            (@opcode & 15) << 11 |
            (@aa & 1) << 10 |
            (@tc & 1) << 9 |
            (@rd & 1) << 8 |
            (@ra & 1) << 7 |
            (@rcode & 15),
            @question.length,
            @answer.length,
            @authority.length,
            @additional.length)
          @question.each {|q|
            name, typeclass = q
            msg.put_name(name)
            msg.put_pack('nn', typeclass::TypeValue, typeclass::ClassValue)
          }
          [@answer, @authority, @additional].each {|rr|
            rr.each {|r|
              name, ttl, data = r
              msg.put_name(name)
              msg.put_pack('nnN', data.class::TypeValue, data.class::ClassValue, ttl)
              msg.put_length16 {data.encode_rdata(msg)}
            }
          }
        }.to_s
      end

      class MessageEncoder # :nodoc:
        def initialize
          @data = ''
          @names = {}
          yield self
        end

        def to_s
          return @data
        end

        def put_bytes(d)
          @data << d
        end

        def put_pack(template, *d)
          @data << d.pack(template)
        end

        def put_length16
          length_index = @data.length
          @data << "\0\0"
          data_start = @data.length
          yield
          data_end = @data.length
          @data[length_index, 2] = [data_end - data_start].pack("n")
        end

        def put_string(d)
          self.put_pack("C", d.length)
          @data << d
        end

        def put_string_list(ds)
          ds.each {|d|
            self.put_string(d)
          }
        end

        def put_name(d)
          put_labels(d.to_a)
        end

        def put_labels(d)
          d.each_index {|i|
            domain = d[i..-1]
            if idx = @names[domain]
              self.put_pack("n", 0xc000 | idx)
              return
            else
              @names[domain] = @data.length
              self.put_label(d[i])
            end
          }
          @data << "\0"
        end

        def put_label(d)
          self.put_string(d.to_s)
        end
      end

      def Message.decode(m)
        o = Message.new(0)
        MessageDecoder.new(m) {|msg|
          id, flag, qdcount, ancount, nscount, arcount =
            msg.get_unpack('nnnnnn')
          o.id = id
          o.qr = (flag >> 15) & 1
          o.opcode = (flag >> 11) & 15
          o.aa = (flag >> 10) & 1
          o.tc = (flag >> 9) & 1
          o.rd = (flag >> 8) & 1
          o.ra = (flag >> 7) & 1
          o.rcode = flag & 15
          (1..qdcount).each {
            name, typeclass = msg.get_question
            o.add_question(name, typeclass)
          }
          (1..ancount).each {
            name, ttl, data = msg.get_rr
            o.add_answer(name, ttl, data)
          }
          (1..nscount).each {
            name, ttl, data = msg.get_rr
            o.add_authority(name, ttl, data)
          }
          (1..arcount).each {
            name, ttl, data = msg.get_rr
            o.add_additional(name, ttl, data)
          }
        }
        return o
      end

      class MessageDecoder # :nodoc:
        def initialize(data)
          @data = data
          @index = 0
          @limit = data.length
          yield self
        end

        def inspect
          "\#<#{self.class}: #{@data[0, @index].inspect} #{@data[@index..-1].inspect}>"
        end

        def get_length16
          len, = self.get_unpack('n')
          save_limit = @limit
          @limit = @index + len
          d = yield(len)
          if @index < @limit
            raise DecodeError.new("junk exists")
          elsif @limit < @index
            raise DecodeError.new("limit exceeded")
          end
          @limit = save_limit
          return d
        end

        def get_bytes(len = @limit - @index)
          raise DecodeError.new("limit exceeded") if @limit < @index + len
          d = @data[@index, len]
          @index += len
          return d
        end

        def get_unpack(template)
          len = 0
          template.each_byte {|byte|
            byte = "%c" % byte
            case byte
            when ?c, ?C
              len += 1
            when ?n
              len += 2
            when ?N
              len += 4
            else
              raise StandardError.new("unsupported template: '#{byte.chr}' in '#{template}'")
            end
          }
          raise DecodeError.new("limit exceeded") if @limit < @index + len
          arr = @data.unpack("@#{@index}#{template}")
          @index += len
          return arr
        end

        def get_string
          raise DecodeError.new("limit exceeded") if @limit <= @index
          len = @data[@index].ord
          raise DecodeError.new("limit exceeded") if @limit < @index + 1 + len
          d = @data[@index + 1, len]
          @index += 1 + len
          return d
        end

        def get_string_list
          strings = []
          while @index < @limit
            strings << self.get_string
          end
          strings
        end

        def get_name
          return Name.new(self.get_labels)
        end

        def get_labels
          prev_index = @index
          save_index = nil
          d = []
          while true
            raise DecodeError.new("limit exceeded") if @limit <= @index
            case @data[@index].ord
            when 0
              @index += 1
              if save_index
                @index = save_index
              end
              return d
            when 192..255
              idx = self.get_unpack('n')[0] & 0x3fff
              if prev_index <= idx
                raise DecodeError.new("non-backward name pointer")
              end
              prev_index = idx
              if !save_index
                save_index = @index
              end
              @index = idx
            else
              d << self.get_label
            end
          end
        end

        def get_label
          return Label::Str.new(self.get_string)
        end

        def get_question
          name = self.get_name
          type, klass = self.get_unpack("nn")
          return name, Resource.get_class(type, klass)
        end

        def get_rr
          name = self.get_name
          type, klass, ttl = self.get_unpack('nnN')
          typeclass = Resource.get_class(type, klass)
          res = self.get_length16 { typeclass.decode_rdata self }
          #nodyna <instance_variable_set-1901> <not yet classified>
          res.instance_variable_set :@ttl, ttl
          return name, ttl, res
        end
      end
    end


    class Query
      def encode_rdata(msg) # :nodoc:
        raise EncodeError.new("#{self.class} is query.")
      end

      def self.decode_rdata(msg) # :nodoc:
        raise DecodeError.new("#{self.class} is query.")
      end
    end


    class Resource < Query


      attr_reader :ttl

      ClassHash = {} # :nodoc:

      def encode_rdata(msg) # :nodoc:
        raise NotImplementedError.new
      end

      def self.decode_rdata(msg) # :nodoc:
        raise NotImplementedError.new
      end

      def ==(other) # :nodoc:
        return false unless self.class == other.class
        s_ivars = self.instance_variables
        s_ivars.sort!
        s_ivars.delete :@ttl
        o_ivars = other.instance_variables
        o_ivars.sort!
        o_ivars.delete :@ttl
        return s_ivars == o_ivars &&
          #nodyna <instance_variable_get-1902> <not yet classified>
          s_ivars.collect {|name| self.instance_variable_get name} ==
            #nodyna <instance_variable_get-1903> <not yet classified>
            o_ivars.collect {|name| other.instance_variable_get name}
      end

      def eql?(other) # :nodoc:
        return self == other
      end

      def hash # :nodoc:
        h = 0
        vars = self.instance_variables
        vars.delete :@ttl
        vars.each {|name|
          #nodyna <instance_variable_get-1904> <not yet classified>
          h ^= self.instance_variable_get(name).hash
        }
        return h
      end

      def self.get_class(type_value, class_value) # :nodoc:
        return ClassHash[[type_value, class_value]] ||
               Generic.create(type_value, class_value)
      end


      class Generic < Resource


        def initialize(data)
          @data = data
        end


        attr_reader :data

        def encode_rdata(msg) # :nodoc:
          msg.put_bytes(data)
        end

        def self.decode_rdata(msg) # :nodoc:
          return self.new(msg.get_bytes)
        end

        def self.create(type_value, class_value) # :nodoc:
          c = Class.new(Generic)
          #nodyna <const_set-1905> <CS TRIVIAL (static values)>
          c.const_set(:TypeValue, type_value)
          #nodyna <const_set-1906> <CS TRIVIAL (static values)>
          c.const_set(:ClassValue, class_value)
          #nodyna <const_set-1907> <CS COMPLEX (change-prone variable)>
          Generic.const_set("Type#{type_value}_Class#{class_value}", c)
          ClassHash[[type_value, class_value]] = c
          return c
        end
      end


      class DomainName < Resource


        def initialize(name)
          @name = name
        end


        attr_reader :name

        def encode_rdata(msg) # :nodoc:
          msg.put_name(@name)
        end

        def self.decode_rdata(msg) # :nodoc:
          return self.new(msg.get_name)
        end
      end


      ClassValue = nil # :nodoc:


      class NS < DomainName
        TypeValue = 2 # :nodoc:
      end


      class CNAME < DomainName
        TypeValue = 5 # :nodoc:
      end


      class SOA < Resource

        TypeValue = 6 # :nodoc:


        def initialize(mname, rname, serial, refresh, retry_, expire, minimum)
          @mname = mname
          @rname = rname
          @serial = serial
          @refresh = refresh
          @retry = retry_
          @expire = expire
          @minimum = minimum
        end


        attr_reader :mname


        attr_reader :rname


        attr_reader :serial


        attr_reader :refresh


        attr_reader :retry


        attr_reader :expire


        attr_reader :minimum

        def encode_rdata(msg) # :nodoc:
          msg.put_name(@mname)
          msg.put_name(@rname)
          msg.put_pack('NNNNN', @serial, @refresh, @retry, @expire, @minimum)
        end

        def self.decode_rdata(msg) # :nodoc:
          mname = msg.get_name
          rname = msg.get_name
          serial, refresh, retry_, expire, minimum = msg.get_unpack('NNNNN')
          return self.new(
            mname, rname, serial, refresh, retry_, expire, minimum)
        end
      end


      class PTR < DomainName
        TypeValue = 12 # :nodoc:
      end


      class HINFO < Resource

        TypeValue = 13 # :nodoc:


        def initialize(cpu, os)
          @cpu = cpu
          @os = os
        end


        attr_reader :cpu


        attr_reader :os

        def encode_rdata(msg) # :nodoc:
          msg.put_string(@cpu)
          msg.put_string(@os)
        end

        def self.decode_rdata(msg) # :nodoc:
          cpu = msg.get_string
          os = msg.get_string
          return self.new(cpu, os)
        end
      end


      class MINFO < Resource

        TypeValue = 14 # :nodoc:

        def initialize(rmailbx, emailbx)
          @rmailbx = rmailbx
          @emailbx = emailbx
        end


        attr_reader :rmailbx


        attr_reader :emailbx

        def encode_rdata(msg) # :nodoc:
          msg.put_name(@rmailbx)
          msg.put_name(@emailbx)
        end

        def self.decode_rdata(msg) # :nodoc:
          rmailbx = msg.get_string
          emailbx = msg.get_string
          return self.new(rmailbx, emailbx)
        end
      end


      class MX < Resource

        TypeValue= 15 # :nodoc:


        def initialize(preference, exchange)
          @preference = preference
          @exchange = exchange
        end


        attr_reader :preference


        attr_reader :exchange

        def encode_rdata(msg) # :nodoc:
          msg.put_pack('n', @preference)
          msg.put_name(@exchange)
        end

        def self.decode_rdata(msg) # :nodoc:
          preference, = msg.get_unpack('n')
          exchange = msg.get_name
          return self.new(preference, exchange)
        end
      end


      class TXT < Resource

        TypeValue = 16 # :nodoc:

        def initialize(first_string, *rest_strings)
          @strings = [first_string, *rest_strings]
        end


        attr_reader :strings


        def data
          @strings.join("")
        end

        def encode_rdata(msg) # :nodoc:
          msg.put_string_list(@strings)
        end

        def self.decode_rdata(msg) # :nodoc:
          strings = msg.get_string_list
          return self.new(*strings)
        end
      end


      class LOC < Resource

        TypeValue = 29 # :nodoc:

        def initialize(version, ssize, hprecision, vprecision, latitude, longitude, altitude)
          @version    = version
          @ssize      = Resolv::LOC::Size.create(ssize)
          @hprecision = Resolv::LOC::Size.create(hprecision)
          @vprecision = Resolv::LOC::Size.create(vprecision)
          @latitude   = Resolv::LOC::Coord.create(latitude)
          @longitude  = Resolv::LOC::Coord.create(longitude)
          @altitude   = Resolv::LOC::Alt.create(altitude)
        end


        attr_reader :version


        attr_reader :ssize


        attr_reader :hprecision


        attr_reader :vprecision


        attr_reader :latitude


        attr_reader :longitude


        attr_reader :altitude


        def encode_rdata(msg) # :nodoc:
          msg.put_bytes(@version)
          msg.put_bytes(@ssize.scalar)
          msg.put_bytes(@hprecision.scalar)
          msg.put_bytes(@vprecision.scalar)
          msg.put_bytes(@latitude.coordinates)
          msg.put_bytes(@longitude.coordinates)
          msg.put_bytes(@altitude.altitude)
        end

        def self.decode_rdata(msg) # :nodoc:
          version    = msg.get_bytes(1)
          ssize      = msg.get_bytes(1)
          hprecision = msg.get_bytes(1)
          vprecision = msg.get_bytes(1)
          latitude   = msg.get_bytes(4)
          longitude  = msg.get_bytes(4)
          altitude   = msg.get_bytes(4)
          return self.new(
            version,
            Resolv::LOC::Size.new(ssize),
            Resolv::LOC::Size.new(hprecision),
            Resolv::LOC::Size.new(vprecision),
            Resolv::LOC::Coord.new(latitude,"lat"),
            Resolv::LOC::Coord.new(longitude,"lon"),
            Resolv::LOC::Alt.new(altitude)
          )
        end
      end


      class ANY < Query
        TypeValue = 255 # :nodoc:
      end

      cClassInsensitiveTypes = [ # :nodoc:
        NS, CNAME, SOA, PTR, HINFO, MINFO, MX, TXT, LOC, ANY
      ]


      module IN

        ClassValue = 1 # :nodoc:

        ClassInsensitiveTypes.each {|s|
          c = Class.new(s)
          #nodyna <const_set-1908> <CS TRIVIAL (array)>
          c.const_set(:TypeValue, s::TypeValue)
          #nodyna <const_set-1909> <CS TRIVIAL (array)>
          c.const_set(:ClassValue, ClassValue)
          ClassHash[[s::TypeValue, ClassValue]] = c
          #nodyna <const_set-1910> <CS COMPLEX (change-prone variable)>
          self.const_set(s.name.sub(/.*::/, ''), c)
        }


        class A < Resource
          TypeValue = 1
          ClassValue = IN::ClassValue
          ClassHash[[TypeValue, ClassValue]] = self # :nodoc:


          def initialize(address)
            @address = IPv4.create(address)
          end


          attr_reader :address

          def encode_rdata(msg) # :nodoc:
            msg.put_bytes(@address.address)
          end

          def self.decode_rdata(msg) # :nodoc:
            return self.new(IPv4.new(msg.get_bytes(4)))
          end
        end


        class WKS < Resource
          TypeValue = 11
          ClassValue = IN::ClassValue
          ClassHash[[TypeValue, ClassValue]] = self # :nodoc:

          def initialize(address, protocol, bitmap)
            @address = IPv4.create(address)
            @protocol = protocol
            @bitmap = bitmap
          end


          attr_reader :address


          attr_reader :protocol


          attr_reader :bitmap

          def encode_rdata(msg) # :nodoc:
            msg.put_bytes(@address.address)
            msg.put_pack("n", @protocol)
            msg.put_bytes(@bitmap)
          end

          def self.decode_rdata(msg) # :nodoc:
            address = IPv4.new(msg.get_bytes(4))
            protocol, = msg.get_unpack("n")
            bitmap = msg.get_bytes
            return self.new(address, protocol, bitmap)
          end
        end


        class AAAA < Resource
          TypeValue = 28
          ClassValue = IN::ClassValue
          ClassHash[[TypeValue, ClassValue]] = self # :nodoc:


          def initialize(address)
            @address = IPv6.create(address)
          end


          attr_reader :address

          def encode_rdata(msg) # :nodoc:
            msg.put_bytes(@address.address)
          end

          def self.decode_rdata(msg) # :nodoc:
            return self.new(IPv6.new(msg.get_bytes(16)))
          end
        end


        class SRV < Resource
          TypeValue = 33
          ClassValue = IN::ClassValue
          ClassHash[[TypeValue, ClassValue]] = self # :nodoc:


          def initialize(priority, weight, port, target)
            @priority = priority.to_int
            @weight = weight.to_int
            @port = port.to_int
            @target = Name.create(target)
          end


          attr_reader :priority


          attr_reader :weight


          attr_reader :port


          attr_reader :target

          def encode_rdata(msg) # :nodoc:
            msg.put_pack("n", @priority)
            msg.put_pack("n", @weight)
            msg.put_pack("n", @port)
            msg.put_name(@target)
          end

          def self.decode_rdata(msg) # :nodoc:
            priority, = msg.get_unpack("n")
            weight,   = msg.get_unpack("n")
            port,     = msg.get_unpack("n")
            target    = msg.get_name
            return self.new(priority, weight, port, target)
          end
        end
      end
    end
  end


  class IPv4


    Regex256 = /0
               |1(?:[0-9][0-9]?)?
               |2(?:[0-4][0-9]?|5[0-5]?|[6-9])?
               |[3-9][0-9]?/x
    Regex = /\A(#{Regex256})\.(#{Regex256})\.(#{Regex256})\.(#{Regex256})\z/

    def self.create(arg)
      case arg
      when IPv4
        return arg
      when Regex
        if (0..255) === (a = $1.to_i) &&
           (0..255) === (b = $2.to_i) &&
           (0..255) === (c = $3.to_i) &&
           (0..255) === (d = $4.to_i)
          return self.new([a, b, c, d].pack("CCCC"))
        else
          raise ArgumentError.new("IPv4 address with invalid value: " + arg)
        end
      else
        raise ArgumentError.new("cannot interpret as IPv4 address: #{arg.inspect}")
      end
    end

    def initialize(address) # :nodoc:
      unless address.kind_of?(String)
        raise ArgumentError, 'IPv4 address must be a string'
      end
      unless address.length == 4
        raise ArgumentError, "IPv4 address expects 4 bytes but #{address.length} bytes"
      end
      @address = address
    end



    attr_reader :address

    def to_s # :nodoc:
      return sprintf("%d.%d.%d.%d", *@address.unpack("CCCC"))
    end

    def inspect # :nodoc:
      return "#<#{self.class} #{self}>"
    end


    def to_name
      return DNS::Name.create(
        '%d.%d.%d.%d.in-addr.arpa.' % @address.unpack('CCCC').reverse)
    end

    def ==(other) # :nodoc:
      return @address == other.address
    end

    def eql?(other) # :nodoc:
      return self == other
    end

    def hash # :nodoc:
      return @address.hash
    end
  end


  class IPv6

    Regex_8Hex = /\A
      (?:[0-9A-Fa-f]{1,4}:){7}
         [0-9A-Fa-f]{1,4}
      \z/x


    Regex_CompressedHex = /\A
      ((?:[0-9A-Fa-f]{1,4}(?::[0-9A-Fa-f]{1,4})*)?) ::
      ((?:[0-9A-Fa-f]{1,4}(?::[0-9A-Fa-f]{1,4})*)?)
      \z/x


    Regex_6Hex4Dec = /\A
      ((?:[0-9A-Fa-f]{1,4}:){6,6})
      (\d+)\.(\d+)\.(\d+)\.(\d+)
      \z/x


    Regex_CompressedHex4Dec = /\A
      ((?:[0-9A-Fa-f]{1,4}(?::[0-9A-Fa-f]{1,4})*)?) ::
      ((?:[0-9A-Fa-f]{1,4}:)*)
      (\d+)\.(\d+)\.(\d+)\.(\d+)
      \z/x


    Regex = /
      (?:#{Regex_8Hex}) |
      (?:#{Regex_CompressedHex}) |
      (?:#{Regex_6Hex4Dec}) |
      (?:#{Regex_CompressedHex4Dec})/x


    def self.create(arg)
      case arg
      when IPv6
        return arg
      when String
        address = ''
        if Regex_8Hex =~ arg
          arg.scan(/[0-9A-Fa-f]+/) {|hex| address << [hex.hex].pack('n')}
        elsif Regex_CompressedHex =~ arg
          prefix = $1
          suffix = $2
          a1 = ''
          a2 = ''
          prefix.scan(/[0-9A-Fa-f]+/) {|hex| a1 << [hex.hex].pack('n')}
          suffix.scan(/[0-9A-Fa-f]+/) {|hex| a2 << [hex.hex].pack('n')}
          omitlen = 16 - a1.length - a2.length
          address << a1 << "\0" * omitlen << a2
        elsif Regex_6Hex4Dec =~ arg
          prefix, a, b, c, d = $1, $2.to_i, $3.to_i, $4.to_i, $5.to_i
          if (0..255) === a && (0..255) === b && (0..255) === c && (0..255) === d
            prefix.scan(/[0-9A-Fa-f]+/) {|hex| address << [hex.hex].pack('n')}
            address << [a, b, c, d].pack('CCCC')
          else
            raise ArgumentError.new("not numeric IPv6 address: " + arg)
          end
        elsif Regex_CompressedHex4Dec =~ arg
          prefix, suffix, a, b, c, d = $1, $2, $3.to_i, $4.to_i, $5.to_i, $6.to_i
          if (0..255) === a && (0..255) === b && (0..255) === c && (0..255) === d
            a1 = ''
            a2 = ''
            prefix.scan(/[0-9A-Fa-f]+/) {|hex| a1 << [hex.hex].pack('n')}
            suffix.scan(/[0-9A-Fa-f]+/) {|hex| a2 << [hex.hex].pack('n')}
            omitlen = 12 - a1.length - a2.length
            address << a1 << "\0" * omitlen << a2 << [a, b, c, d].pack('CCCC')
          else
            raise ArgumentError.new("not numeric IPv6 address: " + arg)
          end
        else
          raise ArgumentError.new("not numeric IPv6 address: " + arg)
        end
        return IPv6.new(address)
      else
        raise ArgumentError.new("cannot interpret as IPv6 address: #{arg.inspect}")
      end
    end

    def initialize(address) # :nodoc:
      unless address.kind_of?(String) && address.length == 16
        raise ArgumentError.new('IPv6 address must be 16 bytes')
      end
      @address = address
    end


    attr_reader :address

    def to_s # :nodoc:
      address = sprintf("%X:%X:%X:%X:%X:%X:%X:%X", *@address.unpack("nnnnnnnn"))
      unless address.sub!(/(^|:)0(:0)+(:|$)/, '::')
        address.sub!(/(^|:)0(:|$)/, '::')
      end
      return address
    end

    def inspect # :nodoc:
      return "#<#{self.class} #{self}>"
    end


    def to_name
      return DNS::Name.new(
        @address.unpack("H32")[0].split(//).reverse + ['ip6', 'arpa'])
    end

    def ==(other) # :nodoc:
      return @address == other.address
    end

    def eql?(other) # :nodoc:
      return self == other
    end

    def hash # :nodoc:
      return @address.hash
    end
  end


  class MDNS < DNS


    Port = 5353


    AddressV4 = '224.0.0.251'


    AddressV6 = 'ff02::fb'


    Addresses = [
      [AddressV4, Port],
      [AddressV6, Port],
    ]


    def initialize(config_info=nil)
      if config_info then
        super({ nameserver_port: Addresses }.merge(config_info))
      else
        super(nameserver_port: Addresses)
      end
    end


    def each_address(name)
      name = Resolv::DNS::Name.create(name)

      return unless name.to_a.last == 'local'

      super(name)
    end

    def make_udp_requester # :nodoc:
      nameserver_port = @config.nameserver_port
      Requester::MDNSOneShot.new(*nameserver_port)
    end

  end

  module LOC


    class Size

      Regex = /^(\d+\.*\d*)[m]$/


      def self.create(arg)
        case arg
        when Size
          return arg
        when String
          scalar = ''
          if Regex =~ arg
            scalar = [(($1.to_f*(1e2)).to_i.to_s[0].to_i*(2**4)+(($1.to_f*(1e2)).to_i.to_s.length-1))].pack("C")
          else
            raise ArgumentError.new("not a properly formed Size string: " + arg)
          end
          return Size.new(scalar)
        else
          raise ArgumentError.new("cannot interpret as Size: #{arg.inspect}")
        end
      end

      def initialize(scalar)
        @scalar = scalar
      end


      attr_reader :scalar

      def to_s # :nodoc:
        s = @scalar.unpack("H2").join.to_s
        return ((s[0].to_i)*(10**(s[1].to_i-2))).to_s << "m"
      end

      def inspect # :nodoc:
        return "#<#{self.class} #{self}>"
      end

      def ==(other) # :nodoc:
        return @scalar == other.scalar
      end

      def eql?(other) # :nodoc:
        return self == other
      end

      def hash # :nodoc:
        return @scalar.hash
      end

    end


    class Coord

      Regex = /^(\d+)\s(\d+)\s(\d+\.\d+)\s([NESW])$/


      def self.create(arg)
        case arg
        when Coord
          return arg
        when String
          coordinates = ''
          if Regex =~ arg &&  $1<180
            hemi = ($4[/([NE])/,1]) || ($4[/([SW])/,1]) ? 1 : -1
            coordinates = [(($1.to_i*(36e5))+($2.to_i*(6e4))+($3.to_f*(1e3)))*hemi+(2**31)].pack("N")
            (orientation ||= '') << $4[[/NS/],1] ? 'lat' : 'lon'
          else
            raise ArgumentError.new("not a properly formed Coord string: " + arg)
          end
          return Coord.new(coordinates,orientation)
        else
          raise ArgumentError.new("cannot interpret as Coord: #{arg.inspect}")
        end
      end

      def initialize(coordinates,orientation)
        unless coordinates.kind_of?(String)
          raise ArgumentError.new("Coord must be a 32bit unsigned integer in hex format: #{coordinates.inspect}")
        end
        unless orientation.kind_of?(String) && orientation[/^lon$|^lat$/]
          raise ArgumentError.new('Coord expects orientation to be a String argument of "lat" or "lon"')
        end
        @coordinates = coordinates
        @orientation = orientation
      end


      attr_reader :coordinates


      attr_reader :orientation

      def to_s # :nodoc:
          c = @coordinates.unpack("N").join.to_i
          val      = (c - (2**31)).abs
          fracsecs = (val % 1e3).to_i.to_s
          val      = val / 1e3
          secs     = (val % 60).to_i.to_s
          val      = val / 60
          mins     = (val % 60).to_i.to_s
          degs     = (val / 60).to_i.to_s
          posi = (c >= 2**31)
          case posi
          when true
            hemi = @orientation[/^lat$/] ? "N" : "E"
          else
            hemi = @orientation[/^lon$/] ? "W" : "S"
          end
          return degs << " " << mins << " " << secs << "." << fracsecs << " " << hemi
      end

      def inspect # :nodoc:
        return "#<#{self.class} #{self}>"
      end

      def ==(other) # :nodoc:
        return @coordinates == other.coordinates
      end

      def eql?(other) # :nodoc:
        return self == other
      end

      def hash # :nodoc:
        return @coordinates.hash
      end

    end


    class Alt

      Regex = /^([+-]*\d+\.*\d*)[m]$/


      def self.create(arg)
        case arg
        when Alt
          return arg
        when String
          altitude = ''
          if Regex =~ arg
            altitude = [($1.to_f*(1e2))+(1e7)].pack("N")
          else
            raise ArgumentError.new("not a properly formed Alt string: " + arg)
          end
          return Alt.new(altitude)
        else
          raise ArgumentError.new("cannot interpret as Alt: #{arg.inspect}")
        end
      end

      def initialize(altitude)
        @altitude = altitude
      end


      attr_reader :altitude

      def to_s # :nodoc:
        a = @altitude.unpack("N").join.to_i
        return ((a.to_f/1e2)-1e5).to_s + "m"
      end

      def inspect # :nodoc:
        return "#<#{self.class} #{self}>"
      end

      def ==(other) # :nodoc:
        return @altitude == other.altitude
      end

      def eql?(other) # :nodoc:
        return self == other
      end

      def hash # :nodoc:
        return @altitude.hash
      end

    end

  end


  DefaultResolver = self.new


  def DefaultResolver.replace_resolvers new_resolvers
    @resolvers = new_resolvers
  end


  AddressRegex = /(?:#{IPv4::Regex})|(?:#{IPv6::Regex})/

end

