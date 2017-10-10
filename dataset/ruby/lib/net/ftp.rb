
require "socket"
require "monitor"
require "net/protocol"

module Net

  class FTPError < StandardError; end
  class FTPReplyError < FTPError; end
  class FTPTempError < FTPError; end
  class FTPPermError < FTPError; end
  class FTPProtoError < FTPError; end
  class FTPConnectionError < FTPError; end

  class FTP
    include MonitorMixin

    FTP_PORT = 21
    CRLF = "\r\n"
    DEFAULT_BLOCKSIZE = BufferedIO::BUFSIZE

    attr_reader :binary

    attr_accessor :passive

    attr_accessor :debug_mode

    attr_accessor :resume

    attr_accessor :open_timeout

    attr_reader :read_timeout

    def read_timeout=(sec)
      @sock.read_timeout = sec
      @read_timeout = sec
    end

    attr_reader :welcome

    attr_reader :last_response_code
    alias lastresp last_response_code

    attr_reader :last_response

    def FTP.open(host, user = nil, passwd = nil, acct = nil)
      if block_given?
        ftp = new(host, user, passwd, acct)
        begin
          yield ftp
        ensure
          ftp.close
        end
      else
        new(host, user, passwd, acct)
      end
    end

    def initialize(host = nil, user = nil, passwd = nil, acct = nil)
      super()
      @binary = true
      @passive = false
      @debug_mode = false
      @resume = false
      @sock = NullSocket.new
      @logged_in = false
      @open_timeout = nil
      @read_timeout = 60
      if host
        connect(host)
        if user
          login(user, passwd, acct)
        end
      end
    end

    def binary=(newmode)
      if newmode != @binary
        @binary = newmode
        send_type_command if @logged_in
      end
    end

    def send_type_command # :nodoc:
      if @binary
        voidcmd("TYPE I")
      else
        voidcmd("TYPE A")
      end
    end
    private :send_type_command

    def with_binary(newmode) # :nodoc:
      oldmode = binary
      self.binary = newmode
      begin
        yield
      ensure
        self.binary = oldmode
      end
    end
    private :with_binary

    def return_code # :nodoc:
      $stderr.puts("warning: Net::FTP#return_code is obsolete and do nothing")
      return "\n"
    end

    def return_code=(s) # :nodoc:
      $stderr.puts("warning: Net::FTP#return_code= is obsolete and do nothing")
    end

    def open_socket(host, port) # :nodoc:
      return Timeout.timeout(@open_timeout, Net::OpenTimeout) {
        if defined? SOCKSSocket and ENV["SOCKS_SERVER"]
          @passive = true
          sock = SOCKSSocket.open(host, port)
        else
          sock = TCPSocket.open(host, port)
        end
        io = BufferedSocket.new(sock)
        io.read_timeout = @read_timeout
        io
      }
    end
    private :open_socket

    def connect(host, port = FTP_PORT)
      if @debug_mode
        print "connect: ", host, ", ", port, "\n"
      end
      synchronize do
        @sock = open_socket(host, port)
        voidresp
      end
    end

    def set_socket(sock, get_greeting = true)
      synchronize do
        @sock = sock
        if get_greeting
          voidresp
        end
      end
    end

    def sanitize(s) # :nodoc:
      if s =~ /^PASS /i
        return s[0, 5] + "*" * (s.length - 5)
      else
        return s
      end
    end
    private :sanitize

    def putline(line) # :nodoc:
      if @debug_mode
        print "put: ", sanitize(line), "\n"
      end
      line = line + CRLF
      @sock.write(line)
    end
    private :putline

    def getline # :nodoc:
      line = @sock.readline # if get EOF, raise EOFError
      line.sub!(/(\r\n|\n|\r)\z/n, "")
      if @debug_mode
        print "get: ", sanitize(line), "\n"
      end
      return line
    end
    private :getline

    def getmultiline # :nodoc:
      line = getline
      buff = line
      if line[3] == ?-
          code = line[0, 3]
        begin
          line = getline
          buff << "\n" << line
        end until line[0, 3] == code and line[3] != ?-
      end
      return buff << "\n"
    end
    private :getmultiline

    def getresp # :nodoc:
      @last_response = getmultiline
      @last_response_code = @last_response[0, 3]
      case @last_response_code
      when /\A[123]/
        return @last_response
      when /\A4/
        raise FTPTempError, @last_response
      when /\A5/
        raise FTPPermError, @last_response
      else
        raise FTPProtoError, @last_response
      end
    end
    private :getresp

    def voidresp # :nodoc:
      resp = getresp
      if resp[0] != ?2
        raise FTPReplyError, resp
      end
    end
    private :voidresp

    def sendcmd(cmd)
      synchronize do
        putline(cmd)
        return getresp
      end
    end

    def voidcmd(cmd)
      synchronize do
        putline(cmd)
        voidresp
      end
    end

    def sendport(host, port) # :nodoc:
      af = (@sock.peeraddr)[0]
      if af == "AF_INET"
        cmd = "PORT " + (host.split(".") + port.divmod(256)).join(",")
      elsif af == "AF_INET6"
        cmd = sprintf("EPRT |2|%s|%d|", host, port)
      else
        raise FTPProtoError, host
      end
      voidcmd(cmd)
    end
    private :sendport

    def makeport # :nodoc:
      TCPServer.open(@sock.addr[3], 0)
    end
    private :makeport

    def makepasv # :nodoc:
      if @sock.peeraddr[0] == "AF_INET"
        host, port = parse227(sendcmd("PASV"))
      else
        host, port = parse229(sendcmd("EPSV"))
      end
      return host, port
    end
    private :makepasv

    def transfercmd(cmd, rest_offset = nil) # :nodoc:
      if @passive
        host, port = makepasv
        conn = open_socket(host, port)
        if @resume and rest_offset
          resp = sendcmd("REST " + rest_offset.to_s)
          if resp[0] != ?3
            raise FTPReplyError, resp
          end
        end
        resp = sendcmd(cmd)
        resp = getresp if resp[0] == ?2
        if resp[0] != ?1
          raise FTPReplyError, resp
        end
      else
        sock = makeport
        begin
          sendport(sock.addr[3], sock.addr[1])
          if @resume and rest_offset
            resp = sendcmd("REST " + rest_offset.to_s)
            if resp[0] != ?3
              raise FTPReplyError, resp
            end
          end
          resp = sendcmd(cmd)
          resp = getresp if resp[0] == ?2
          if resp[0] != ?1
            raise FTPReplyError, resp
          end
          conn = BufferedSocket.new(sock.accept)
          conn.read_timeout = @read_timeout
          sock.shutdown(Socket::SHUT_WR) rescue nil
          sock.read rescue nil
        ensure
          sock.close
        end
      end
      return conn
    end
    private :transfercmd

    def login(user = "anonymous", passwd = nil, acct = nil)
      if user == "anonymous" and passwd == nil
        passwd = "anonymous@"
      end

      resp = ""
      synchronize do
        resp = sendcmd('USER ' + user)
        if resp[0] == ?3
          raise FTPReplyError, resp if passwd.nil?
          resp = sendcmd('PASS ' + passwd)
        end
        if resp[0] == ?3
          raise FTPReplyError, resp if acct.nil?
          resp = sendcmd('ACCT ' + acct)
        end
      end
      if resp[0] != ?2
        raise FTPReplyError, resp
      end
      @welcome = resp
      send_type_command
      @logged_in = true
    end

    def retrbinary(cmd, blocksize, rest_offset = nil) # :yield: data
      synchronize do
        with_binary(true) do
          begin
            conn = transfercmd(cmd, rest_offset)
            loop do
              data = conn.read(blocksize)
              break if data == nil
              yield(data)
            end
            conn.shutdown(Socket::SHUT_WR)
            conn.read_timeout = 1
            conn.read
          ensure
            conn.close if conn
          end
          voidresp
        end
      end
    end

    def retrlines(cmd) # :yield: line
      synchronize do
        with_binary(false) do
          begin
            conn = transfercmd(cmd)
            loop do
              line = conn.gets
              break if line == nil
              yield(line.sub(/\r?\n\z/, ""), !line.match(/\n\z/).nil?)
            end
            conn.shutdown(Socket::SHUT_WR)
            conn.read_timeout = 1
            conn.read
          ensure
            conn.close if conn
          end
          voidresp
        end
      end
    end

    def storbinary(cmd, file, blocksize, rest_offset = nil) # :yield: data
      if rest_offset
        file.seek(rest_offset, IO::SEEK_SET)
      end
      synchronize do
        with_binary(true) do
          conn = transfercmd(cmd)
          loop do
            buf = file.read(blocksize)
            break if buf == nil
            conn.write(buf)
            yield(buf) if block_given?
          end
          conn.close
          voidresp
        end
      end
    rescue Errno::EPIPE
      getresp
      raise
    end

    def storlines(cmd, file) # :yield: line
      synchronize do
        with_binary(false) do
          conn = transfercmd(cmd)
          loop do
            buf = file.gets
            break if buf == nil
            if buf[-2, 2] != CRLF
              buf = buf.chomp + CRLF
            end
            conn.write(buf)
            yield(buf) if block_given?
          end
          conn.close
          voidresp
        end
      end
    rescue Errno::EPIPE
      getresp
      raise
    end

    def getbinaryfile(remotefile, localfile = File.basename(remotefile),
                      blocksize = DEFAULT_BLOCKSIZE) # :yield: data
      result = nil
      if localfile
        if @resume
          rest_offset = File.size?(localfile)
          f = open(localfile, "a")
        else
          rest_offset = nil
          f = open(localfile, "w")
        end
      elsif !block_given?
        result = ""
      end
      begin
        f.binmode if localfile
        retrbinary("RETR " + remotefile.to_s, blocksize, rest_offset) do |data|
          f.write(data) if localfile
          yield(data) if block_given?
          result.concat(data) if result
        end
        return result
      ensure
        f.close if localfile
      end
    end

    def gettextfile(remotefile, localfile = File.basename(remotefile)) # :yield: line
      result = nil
      if localfile
        f = open(localfile, "w")
      elsif !block_given?
        result = ""
      end
      begin
        retrlines("RETR " + remotefile) do |line, newline|
          l = newline ? line + "\n" : line
          f.print(l) if localfile
          yield(line, newline) if block_given?
          result.concat(l) if result
        end
        return result
      ensure
        f.close if localfile
      end
    end

    def get(remotefile, localfile = File.basename(remotefile),
            blocksize = DEFAULT_BLOCKSIZE, &block) # :yield: data
      if @binary
        getbinaryfile(remotefile, localfile, blocksize, &block)
      else
        gettextfile(remotefile, localfile, &block)
      end
    end

    def putbinaryfile(localfile, remotefile = File.basename(localfile),
                      blocksize = DEFAULT_BLOCKSIZE, &block) # :yield: data
      if @resume
        begin
          rest_offset = size(remotefile)
        rescue Net::FTPPermError
          rest_offset = nil
        end
      else
        rest_offset = nil
      end
      f = open(localfile)
      begin
        f.binmode
        if rest_offset
          storbinary("APPE " + remotefile, f, blocksize, rest_offset, &block)
        else
          storbinary("STOR " + remotefile, f, blocksize, rest_offset, &block)
        end
      ensure
        f.close
      end
    end

    def puttextfile(localfile, remotefile = File.basename(localfile), &block) # :yield: line
      f = open(localfile)
      begin
        storlines("STOR " + remotefile, f, &block)
      ensure
        f.close
      end
    end

    def put(localfile, remotefile = File.basename(localfile),
            blocksize = DEFAULT_BLOCKSIZE, &block)
      if @binary
        putbinaryfile(localfile, remotefile, blocksize, &block)
      else
        puttextfile(localfile, remotefile, &block)
      end
    end

    def acct(account)
      cmd = "ACCT " + account
      voidcmd(cmd)
    end

    def nlst(dir = nil)
      cmd = "NLST"
      if dir
        cmd = cmd + " " + dir
      end
      files = []
      retrlines(cmd) do |line|
        files.push(line)
      end
      return files
    end

    def list(*args, &block) # :yield: line
      cmd = "LIST"
      args.each do |arg|
        cmd = cmd + " " + arg.to_s
      end
      if block
        retrlines(cmd, &block)
      else
        lines = []
        retrlines(cmd) do |line|
          lines << line
        end
        return lines
      end
    end
    alias ls list
    alias dir list

    def rename(fromname, toname)
      resp = sendcmd("RNFR " + fromname)
      if resp[0] != ?3
        raise FTPReplyError, resp
      end
      voidcmd("RNTO " + toname)
    end

    def delete(filename)
      resp = sendcmd("DELE " + filename)
      if resp[0, 3] == "250"
        return
      elsif resp[0] == ?5
        raise FTPPermError, resp
      else
        raise FTPReplyError, resp
      end
    end

    def chdir(dirname)
      if dirname == ".."
        begin
          voidcmd("CDUP")
          return
        rescue FTPPermError => e
          if e.message[0, 3] != "500"
            raise e
          end
        end
      end
      cmd = "CWD " + dirname
      voidcmd(cmd)
    end

    def size(filename)
      with_binary(true) do
        resp = sendcmd("SIZE " + filename)
        if resp[0, 3] != "213"
          raise FTPReplyError, resp
        end
        return resp[3..-1].strip.to_i
      end
    end

    MDTM_REGEXP = /^(\d\d\d\d)(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)/  # :nodoc:

    def mtime(filename, local = false)
      str = mdtm(filename)
      ary = str.scan(MDTM_REGEXP)[0].collect {|i| i.to_i}
      return local ? Time.local(*ary) : Time.gm(*ary)
    end

    def mkdir(dirname)
      resp = sendcmd("MKD " + dirname)
      return parse257(resp)
    end

    def rmdir(dirname)
      voidcmd("RMD " + dirname)
    end

    def pwd
      resp = sendcmd("PWD")
      return parse257(resp)
    end
    alias getdir pwd

    def system
      resp = sendcmd("SYST")
      if resp[0, 3] != "215"
        raise FTPReplyError, resp
      end
      return resp[4 .. -1]
    end

    def abort
      line = "ABOR" + CRLF
      print "put: ABOR\n" if @debug_mode
      #nodyna <send-2155> <SD EASY (private methods)>
      @sock.send(line, Socket::MSG_OOB)
      resp = getmultiline
      unless ["426", "226", "225"].include?(resp[0, 3])
        raise FTPProtoError, resp
      end
      return resp
    end

    def status
      line = "STAT" + CRLF
      print "put: STAT\n" if @debug_mode
      #nodyna <send-2156> <SD EASY (private methods)>
      @sock.send(line, Socket::MSG_OOB)
      return getresp
    end

    def mdtm(filename)
      resp = sendcmd("MDTM " + filename)
      if resp[0, 3] == "213"
        return resp[3 .. -1].strip
      end
    end

    def help(arg = nil)
      cmd = "HELP"
      if arg
        cmd = cmd + " " + arg
      end
      sendcmd(cmd)
    end

    def quit
      voidcmd("QUIT")
    end

    def noop
      voidcmd("NOOP")
    end

    def site(arg)
      cmd = "SITE " + arg
      voidcmd(cmd)
    end

    def close
      if @sock and not @sock.closed?
        begin
          @sock.shutdown(Socket::SHUT_WR) rescue nil
          orig, self.read_timeout = self.read_timeout, 3
          @sock.read rescue nil
        ensure
          @sock.close
          self.read_timeout = orig
        end
      end
    end

    def closed?
      @sock == nil or @sock.closed?
    end

    def parse227(resp) # :nodoc:
      if resp[0, 3] != "227"
        raise FTPReplyError, resp
      end
      if m = /\((?<host>\d+(,\d+){3}),(?<port>\d+,\d+)\)/.match(resp)
        return parse_pasv_ipv4_host(m["host"]), parse_pasv_port(m["port"])
      else
        raise FTPProtoError, resp
      end
    end
    private :parse227

    def parse228(resp) # :nodoc:
      if resp[0, 3] != "228"
        raise FTPReplyError, resp
      end
      if m = /\(4,4,(?<host>\d+(,\d+){3}),2,(?<port>\d+,\d+)\)/.match(resp)
        return parse_pasv_ipv4_host(m["host"]), parse_pasv_port(m["port"])
      elsif m = /\(6,16,(?<host>\d+(,(\d+)){15}),2,(?<port>\d+,\d+)\)/.match(resp)
        return parse_pasv_ipv6_host(m["host"]), parse_pasv_port(m["port"])
      else
        raise FTPProtoError, resp
      end
    end
    private :parse228

    def parse_pasv_ipv4_host(s)
      return s.tr(",", ".")
    end
    private :parse_pasv_ipv4_host

    def parse_pasv_ipv6_host(s)
      return s.split(/,/).map { |i|
        "%02x" % i.to_i
      }.each_slice(2).map(&:join).join(":")
    end
    private :parse_pasv_ipv6_host

    def parse_pasv_port(s)
      return s.split(/,/).map(&:to_i).inject { |x, y|
        (x << 8) + y
      }
    end
    private :parse_pasv_port

    def parse229(resp) # :nodoc:
      if resp[0, 3] != "229"
        raise FTPReplyError, resp
      end
      if m = /\((?<d>[!-~])\k<d>\k<d>(?<port>\d+)\k<d>\)/.match(resp)
        return @sock.peeraddr[3], m["port"].to_i
      else
        raise FTPProtoError, resp
      end
    end
    private :parse229

    def parse257(resp) # :nodoc:
      if resp[0, 3] != "257"
        raise FTPReplyError, resp
      end
      if resp[3, 2] != ' "'
        return ""
      end
      dirname = ""
      i = 5
      n = resp.length
      while i < n
        c = resp[i, 1]
        i = i + 1
        if c == '"'
          if i > n or resp[i, 1] != '"'
            break
          end
          i = i + 1
        end
        dirname = dirname + c
      end
      return dirname
    end
    private :parse257

    class NullSocket
      def read_timeout=(sec)
      end

      def close
      end

      def method_missing(mid, *args)
        raise FTPConnectionError, "not connected"
      end
    end

    class BufferedSocket < BufferedIO
      #nodyna <send-2157> <not yet classified>
      [:addr, :peeraddr, :send, :shutdown].each do |method|
        #nodyna <define_method-2158> <DM MODERATE (array)>
        define_method(method) { |*args|
          @io.__send__(method, *args)
        }
      end

      def read(len = nil)
        if len
          s = super(len, "", true)
          return s.empty? ? nil : s
        else
          result = ""
          while s = super(DEFAULT_BLOCKSIZE, "", true)
            break if s.empty?
            result << s
          end
          return result
        end
      end

      def gets
        line = readuntil("\n", true)
        return line.empty? ? nil : line
      end

      def readline
        line = gets
        if line.nil?
          raise EOFError, "end of file reached"
        end
        return line
      end
    end
  end
end


