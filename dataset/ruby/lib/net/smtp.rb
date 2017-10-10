
require 'net/protocol'
require 'digest/md5'
require 'timeout'
begin
  require 'openssl'
rescue LoadError
end

module Net

  module SMTPError
  end

  class SMTPAuthenticationError < ProtoAuthError
    include SMTPError
  end

  class SMTPServerBusy < ProtoServerError
    include SMTPError
  end

  class SMTPSyntaxError < ProtoSyntaxError
    include SMTPError
  end

  class SMTPFatalError < ProtoFatalError
    include SMTPError
  end

  class SMTPUnknownError < ProtoUnknownError
    include SMTPError
  end

  class SMTPUnsupportedCommand < ProtocolError
    include SMTPError
  end

  class SMTP

    Revision = %q$Revision$.split[1]

    def SMTP.default_port
      25
    end

    def SMTP.default_submission_port
      587
    end

    def SMTP.default_tls_port
      465
    end

    class << self
      alias default_ssl_port default_tls_port
    end

    def SMTP.default_ssl_context
      OpenSSL::SSL::SSLContext.new
    end

    def initialize(address, port = nil)
      @address = address
      @port = (port || SMTP.default_port)
      @esmtp = true
      @capabilities = nil
      @socket = nil
      @started = false
      @open_timeout = 30
      @read_timeout = 60
      @error_occurred = false
      @debug_output = nil
      @tls = false
      @starttls = false
      @ssl_context = nil
    end

    def inspect
      "#<#{self.class} #{@address}:#{@port} started=#{@started}>"
    end

    attr_accessor :esmtp

    alias :esmtp? :esmtp

    def capable_starttls?
      capable?('STARTTLS')
    end

    def capable?(key)
      return nil unless @capabilities
      @capabilities[key] ? true : false
    end
    private :capable?

    def capable_plain_auth?
      auth_capable?('PLAIN')
    end

    def capable_login_auth?
      auth_capable?('LOGIN')
    end

    def capable_cram_md5_auth?
      auth_capable?('CRAM-MD5')
    end

    def auth_capable?(type)
      return nil unless @capabilities
      return false unless @capabilities['AUTH']
      @capabilities['AUTH'].include?(type)
    end
    private :auth_capable?

    def capable_auth_types
      return [] unless @capabilities
      return [] unless @capabilities['AUTH']
      @capabilities['AUTH']
    end

    def tls?
      @tls
    end

    alias ssl? tls?

    def enable_tls(context = SMTP.default_ssl_context)
      raise 'openssl library not installed' unless defined?(OpenSSL)
      raise ArgumentError, "SMTPS and STARTTLS is exclusive" if @starttls
      @tls = true
      @ssl_context = context
    end

    alias enable_ssl enable_tls

    def disable_tls
      @tls = false
      @ssl_context = nil
    end

    alias disable_ssl disable_tls

    def starttls?
      @starttls
    end

    def starttls_always?
      @starttls == :always
    end

    def starttls_auto?
      @starttls == :auto
    end

    def enable_starttls(context = SMTP.default_ssl_context)
      raise 'openssl library not installed' unless defined?(OpenSSL)
      raise ArgumentError, "SMTPS and STARTTLS is exclusive" if @tls
      @starttls = :always
      @ssl_context = context
    end

    def enable_starttls_auto(context = SMTP.default_ssl_context)
      raise 'openssl library not installed' unless defined?(OpenSSL)
      raise ArgumentError, "SMTPS and STARTTLS is exclusive" if @tls
      @starttls = :auto
      @ssl_context = context
    end

    def disable_starttls
      @starttls = false
      @ssl_context = nil
    end

    attr_reader :address

    attr_reader :port

    attr_accessor :open_timeout

    attr_reader :read_timeout

    def read_timeout=(sec)
      @socket.read_timeout = sec if @socket
      @read_timeout = sec
    end

    def debug_output=(arg)
      @debug_output = arg
    end

    alias set_debug_output debug_output=


    def SMTP.start(address, port = nil, helo = 'localhost',
                   user = nil, secret = nil, authtype = nil,
                   &block)   # :yield: smtp
      new(address, port).start(helo, user, secret, authtype, &block)
    end

    def started?
      @started
    end

    def start(helo = 'localhost',
              user = nil, secret = nil, authtype = nil)   # :yield: smtp
      if block_given?
        begin
          do_start helo, user, secret, authtype
          return yield(self)
        ensure
          do_finish
        end
      else
        do_start helo, user, secret, authtype
        return self
      end
    end

    def finish
      raise IOError, 'not yet started' unless started?
      do_finish
    end

    private

    def tcp_socket(address, port)
      TCPSocket.open address, port
    end

    def do_start(helo_domain, user, secret, authtype)
      raise IOError, 'SMTP session already started' if @started
      if user or secret
        check_auth_method(authtype || DEFAULT_AUTH_TYPE)
        check_auth_args user, secret
      end
      s = Timeout.timeout(@open_timeout, Net::OpenTimeout) do
        tcp_socket(@address, @port)
      end
      logging "Connection opened: #{@address}:#{@port}"
      @socket = new_internet_message_io(tls? ? tlsconnect(s) : s)
      check_response critical { recv_response() }
      do_helo helo_domain
      if starttls_always? or (capable_starttls? and starttls_auto?)
        unless capable_starttls?
          raise SMTPUnsupportedCommand,
              "STARTTLS is not supported on this server"
        end
        starttls
        @socket = new_internet_message_io(tlsconnect(s))
        do_helo helo_domain
      end
      authenticate user, secret, (authtype || DEFAULT_AUTH_TYPE) if user
      @started = true
    ensure
      unless @started
        s.close if s and not s.closed?
        @socket = nil
      end
    end

    def ssl_socket(socket, context)
      OpenSSL::SSL::SSLSocket.new socket, context
    end

    def tlsconnect(s)
      verified = false
      s = ssl_socket(s, @ssl_context)
      logging "TLS connection started"
      s.sync_close = true
      s.connect
      if @ssl_context.verify_mode != OpenSSL::SSL::VERIFY_NONE
        s.post_connection_check(@address)
      end
      verified = true
      s
    ensure
      s.close unless verified
    end

    def new_internet_message_io(s)
      io = InternetMessageIO.new(s)
      io.read_timeout = @read_timeout
      io.debug_output = @debug_output
      io
    end

    def do_helo(helo_domain)
      res = @esmtp ? ehlo(helo_domain) : helo(helo_domain)
      @capabilities = res.capabilities
    rescue SMTPError
      if @esmtp
        @esmtp = false
        @error_occurred = false
        retry
      end
      raise
    end

    def do_finish
      quit if @socket and not @socket.closed? and not @error_occurred
    ensure
      @started = false
      @error_occurred = false
      @socket.close if @socket and not @socket.closed?
      @socket = nil
    end


    public

    def send_message(msgstr, from_addr, *to_addrs)
      raise IOError, 'closed session' unless @socket
      mailfrom from_addr
      rcptto_list(to_addrs) {data msgstr}
    end

    alias send_mail send_message
    alias sendmail send_message   # obsolete

    def open_message_stream(from_addr, *to_addrs, &block)   # :yield: stream
      raise IOError, 'closed session' unless @socket
      mailfrom from_addr
      rcptto_list(to_addrs) {data(&block)}
    end

    alias ready open_message_stream   # obsolete


    public

    DEFAULT_AUTH_TYPE = :plain

    def authenticate(user, secret, authtype = DEFAULT_AUTH_TYPE)
      check_auth_method authtype
      check_auth_args user, secret
      #nodyna <send-2159> <SD COMPLEX (change-prone variables)>
      send auth_method(authtype), user, secret
    end

    def auth_plain(user, secret)
      check_auth_args user, secret
      res = critical {
        get_response('AUTH PLAIN ' + base64_encode("\0#{user}\0#{secret}"))
      }
      check_auth_response res
      res
    end

    def auth_login(user, secret)
      check_auth_args user, secret
      res = critical {
        check_auth_continue get_response('AUTH LOGIN')
        check_auth_continue get_response(base64_encode(user))
        get_response(base64_encode(secret))
      }
      check_auth_response res
      res
    end

    def auth_cram_md5(user, secret)
      check_auth_args user, secret
      res = critical {
        res0 = get_response('AUTH CRAM-MD5')
        check_auth_continue res0
        crammed = cram_md5_response(secret, res0.cram_md5_challenge)
        get_response(base64_encode("#{user} #{crammed}"))
      }
      check_auth_response res
      res
    end

    private

    def check_auth_method(type)
      unless respond_to?(auth_method(type), true)
        raise ArgumentError, "wrong authentication type #{type}"
      end
    end

    def auth_method(type)
      "auth_#{type.to_s.downcase}".intern
    end

    def check_auth_args(user, secret, authtype = DEFAULT_AUTH_TYPE)
      unless user
        raise ArgumentError, 'SMTP-AUTH requested but missing user name'
      end
      unless secret
        raise ArgumentError, 'SMTP-AUTH requested but missing secret phrase'
      end
    end

    def base64_encode(str)
      [str].pack('m').gsub(/\s+/, '')
    end

    IMASK = 0x36
    OMASK = 0x5c

    def cram_md5_response(secret, challenge)
      tmp = Digest::MD5.digest(cram_secret(secret, IMASK) + challenge)
      Digest::MD5.hexdigest(cram_secret(secret, OMASK) + tmp)
    end

    CRAM_BUFSIZE = 64

    def cram_secret(secret, mask)
      secret = Digest::MD5.digest(secret) if secret.size > CRAM_BUFSIZE
      buf = secret.ljust(CRAM_BUFSIZE, "\0")
      0.upto(buf.size - 1) do |i|
        buf[i] = (buf[i].ord ^ mask).chr
      end
      buf
    end


    public


    def rset
      getok('RSET')
    end

    def starttls
      getok('STARTTLS')
    end

    def helo(domain)
      getok("HELO #{domain}")
    end

    def ehlo(domain)
      getok("EHLO #{domain}")
    end

    def mailfrom(from_addr)
      if $SAFE > 0
        raise SecurityError, 'tainted from_addr' if from_addr.tainted?
      end
      getok("MAIL FROM:<#{from_addr}>")
    end

    def rcptto_list(to_addrs)
      raise ArgumentError, 'mail destination not given' if to_addrs.empty?
      ok_users = []
      unknown_users = []
      to_addrs.flatten.each do |addr|
        begin
          rcptto addr
        rescue SMTPAuthenticationError
          unknown_users << addr.dump
        else
          ok_users << addr
        end
      end
      raise ArgumentError, 'mail destination not given' if ok_users.empty?
      ret = yield
      unless unknown_users.empty?
        raise SMTPAuthenticationError, "failed to deliver for #{unknown_users.join(', ')}"
      end
      ret
    end

    def rcptto(to_addr)
      if $SAFE > 0
        raise SecurityError, 'tainted to_addr' if to_addr.tainted?
      end
      getok("RCPT TO:<#{to_addr}>")
    end

    def data(msgstr = nil, &block)   #:yield: stream
      if msgstr and block
        raise ArgumentError, "message and block are exclusive"
      end
      unless msgstr or block
        raise ArgumentError, "message or block is required"
      end
      res = critical {
        check_continue get_response('DATA')
        socket_sync_bak = @socket.io.sync
        begin
          @socket.io.sync = false
          if msgstr
            @socket.write_message msgstr
          else
            @socket.write_message_by_block(&block)
          end
        ensure
          @socket.io.flush
          @socket.io.sync = socket_sync_bak
        end
        recv_response()
      }
      check_response res
      res
    end

    def quit
      getok('QUIT')
    end

    private

    def getok(reqline)
      res = critical {
        @socket.writeline reqline
        recv_response()
      }
      check_response res
      res
    end

    def get_response(reqline)
      @socket.writeline reqline
      recv_response()
    end

    def recv_response
      buf = ''
      while true
        line = @socket.readline
        buf << line << "\n"
        break unless line[3,1] == '-'   # "210-PIPELINING"
      end
      Response.parse(buf)
    end

    def critical
      return Response.parse('200 dummy reply code') if @error_occurred
      begin
        return yield()
      rescue Exception
        @error_occurred = true
        raise
      end
    end

    def check_response(res)
      unless res.success?
        raise res.exception_class, res.message
      end
    end

    def check_continue(res)
      unless res.continue?
        raise SMTPUnknownError, "could not get 3xx (#{res.status}: #{res.string})"
      end
    end

    def check_auth_response(res)
      unless res.success?
        raise SMTPAuthenticationError, res.message
      end
    end

    def check_auth_continue(res)
      unless res.continue?
        raise res.exception_class, res.message
      end
    end

    class Response
      def self.parse(str)
        new(str[0,3], str)
      end

      def initialize(status, string)
        @status = status
        @string = string
      end

      attr_reader :status

      attr_reader :string

      def status_type_char
        @status[0, 1]
      end

      def success?
        status_type_char() == '2'
      end

      def continue?
        status_type_char() == '3'
      end

      def message
        @string.lines.first
      end

      def cram_md5_challenge
        @string.split(/ /)[1].unpack('m')[0]
      end

      def capabilities
        return {} unless @string[3, 1] == '-'
        h = {}
        @string.lines.drop(1).each do |line|
          k, *v = line[4..-1].chomp.split
          h[k] = v
        end
        h
      end

      def exception_class
        case @status
        when /\A4/  then SMTPServerBusy
        when /\A50/ then SMTPSyntaxError
        when /\A53/ then SMTPAuthenticationError
        when /\A5/  then SMTPFatalError
        else             SMTPUnknownError
        end
      end
    end

    def logging(msg)
      @debug_output << msg + "\n" if @debug_output
    end

  end   # class SMTP

  SMTPSession = SMTP # :nodoc:

end
