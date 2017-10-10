
require 'net/protocol'
require 'digest/md5'
require 'timeout'

begin
  require "openssl"
rescue LoadError
end

module Net

  class POPError < ProtocolError; end

  class POPAuthenticationError < ProtoAuthError; end

  class POPBadResponse < POPError; end

  class POP3 < Protocol

    Revision = %q$Revision$.split[1]


    def POP3.default_port
      default_pop3_port()
    end

    def POP3.default_pop3_port
      110
    end

    def POP3.default_pop3s_port
      995
    end

    def POP3.socket_type   #:nodoc: obsolete
      Net::InternetMessageIO
    end


    def POP3.APOP(isapop)
      isapop ? APOP : POP3
    end

    def POP3.foreach(address, port = nil,
                     account = nil, password = nil,
                     isapop = false, &block)  # :yields: message
      start(address, port, account, password, isapop) {|pop|
        pop.each_mail(&block)
      }
    end

    def POP3.delete_all(address, port = nil,
                        account = nil, password = nil,
                        isapop = false, &block)
      start(address, port, account, password, isapop) {|pop|
        pop.delete_all(&block)
      }
    end

    def POP3.auth_only(address, port = nil,
                       account = nil, password = nil,
                       isapop = false)
      new(address, port, isapop).auth_only account, password
    end

    def auth_only(account, password)
      raise IOError, 'opening previously opened POP session' if started?
      start(account, password) {
        ;
      }
    end


    @ssl_params = nil

    def POP3.enable_ssl(*args)
      @ssl_params = create_ssl_params(*args)
    end

    def POP3.create_ssl_params(verify_or_params = {}, certs = nil)
      begin
        params = verify_or_params.to_hash
      rescue NoMethodError
        params = {}
        params[:verify_mode] = verify_or_params
        if certs
          if File.file?(certs)
            params[:ca_file] = certs
          elsif File.directory?(certs)
            params[:ca_path] = certs
          end
        end
      end
      return params
    end

    def POP3.disable_ssl
      @ssl_params = nil
    end

    def POP3.ssl_params
      return @ssl_params
    end

    def POP3.use_ssl?
      return !@ssl_params.nil?
    end

    def POP3.verify
      return @ssl_params[:verify_mode]
    end

    def POP3.certs
      return @ssl_params[:ca_file] || @ssl_params[:ca_path]
    end


    def POP3.start(address, port = nil,
                   account = nil, password = nil,
                   isapop = false, &block)   # :yield: pop
      new(address, port, isapop).start(account, password, &block)
    end

    def initialize(addr, port = nil, isapop = false)
      @address = addr
      @ssl_params = POP3.ssl_params
      @port = port
      @apop = isapop

      @command = nil
      @socket = nil
      @started = false
      @open_timeout = 30
      @read_timeout = 60
      @debug_output = nil

      @mails = nil
      @n_mails = nil
      @n_bytes = nil
    end

    def apop?
      @apop
    end

    def use_ssl?
      return !@ssl_params.nil?
    end

    def enable_ssl(verify_or_params = {}, certs = nil, port = nil)
      begin
        @ssl_params = verify_or_params.to_hash.dup
        @port = @ssl_params.delete(:port) || @port
      rescue NoMethodError
        @ssl_params = POP3.create_ssl_params(verify_or_params, certs)
        @port = port || @port
      end
    end

    def disable_ssl
      @ssl_params = nil
    end

    def inspect
      "#<#{self.class} #{@address}:#{@port} open=#{@started}>"
    end

    def set_debug_output(arg)
      @debug_output = arg
    end

    attr_reader :address

    def port
      return @port || (use_ssl? ? POP3.default_pop3s_port : POP3.default_pop3_port)
    end

    attr_accessor :open_timeout

    attr_reader :read_timeout

    def read_timeout=(sec)
      @command.socket.read_timeout = sec if @command
      @read_timeout = sec
    end

    def started?
      @started
    end

    alias active? started?   #:nodoc: obsolete

    def start(account, password) # :yield: pop
      raise IOError, 'POP session already started' if @started
      if block_given?
        begin
          do_start account, password
          return yield(self)
        ensure
          do_finish
        end
      else
        do_start account, password
        return self
      end
    end

    def do_start(account, password) # :nodoc:
      s = Timeout.timeout(@open_timeout, Net::OpenTimeout) do
        TCPSocket.open(@address, port)
      end
      if use_ssl?
        raise 'openssl library not installed' unless defined?(OpenSSL)
        context = OpenSSL::SSL::SSLContext.new
        context.set_params(@ssl_params)
        s = OpenSSL::SSL::SSLSocket.new(s, context)
        s.sync_close = true
        s.connect
        if context.verify_mode != OpenSSL::SSL::VERIFY_NONE
          s.post_connection_check(@address)
        end
      end
      @socket = InternetMessageIO.new(s)
      logging "POP session started: #{@address}:#{@port} (#{@apop ? 'APOP' : 'POP'})"
      @socket.read_timeout = @read_timeout
      @socket.debug_output = @debug_output
      on_connect
      @command = POP3Command.new(@socket)
      if apop?
        @command.apop account, password
      else
        @command.auth account, password
      end
      @started = true
    ensure
      unless @started
        s.close if s and not s.closed?
        @socket = nil
        @command = nil
      end
    end
    private :do_start

    def on_connect # :nodoc:
    end
    private :on_connect

    def finish
      raise IOError, 'POP session not yet started' unless started?
      do_finish
    end

    def do_finish # :nodoc:
      @mails = nil
      @n_mails = nil
      @n_bytes = nil
      @command.quit if @command
    ensure
      @started = false
      @command = nil
      @socket.close if @socket and not @socket.closed?
      @socket = nil
    end
    private :do_finish

    def command # :nodoc:
      raise IOError, 'POP session not opened yet' \
                                      if not @socket or @socket.closed?
      @command
    end
    private :command


    def n_mails
      return @n_mails if @n_mails
      @n_mails, @n_bytes = command().stat
      @n_mails
    end

    def n_bytes
      return @n_bytes if @n_bytes
      @n_mails, @n_bytes = command().stat
      @n_bytes
    end

    def mails
      return @mails.dup if @mails
      if n_mails() == 0
        @mails = []
        return []
      end

      @mails = command().list.map {|num, size|
        POPMail.new(num, size, self, command())
      }
      @mails.dup
    end

    def each_mail(&block)  # :yield: message
      mails().each(&block)
    end

    alias each each_mail

    def delete_all # :yield: message
      mails().each do |m|
        yield m if block_given?
        m.delete unless m.deleted?
      end
    end

    def reset
      command().rset
      mails().each do |m|
        #nodyna <instance_eval-2162> <IEV COMPLEX (private access)>
        m.instance_eval {
          @deleted = false
        }
      end
    end

    def set_all_uids   #:nodoc: internal use only (called from POPMail#uidl)
      uidl = command().uidl
      @mails.each {|m| m.uid = uidl[m.number] }
    end

    def logging(msg)
      @debug_output << msg + "\n" if @debug_output
    end

  end   # class POP3

  POP = POP3 # :nodoc:
  POPSession  = POP3 # :nodoc:
  POP3Session = POP3 # :nodoc:

  class APOP < POP3
    def apop?
      true
    end
  end

  APOPSession = APOP

  class POPMail

    def initialize(num, len, pop, cmd)   #:nodoc:
      @number = num
      @length = len
      @pop = pop
      @command = cmd
      @deleted = false
      @uid = nil
    end

    attr_reader :number

    attr_reader :length
    alias size length

    def inspect
      "#<#{self.class} #{@number}#{@deleted ? ' deleted' : ''}>"
    end

    def pop( dest = '', &block ) # :yield: message_chunk
      if block_given?
        @command.retr(@number, &block)
        nil
      else
        @command.retr(@number) do |chunk|
          dest << chunk
        end
        dest
      end
    end

    alias all pop    #:nodoc: obsolete
    alias mail pop   #:nodoc: obsolete

    def top(lines, dest = '')
      @command.top(@number, lines) do |chunk|
        dest << chunk
      end
      dest
    end

    def header(dest = '')
      top(0, dest)
    end

    def delete
      @command.dele @number
      @deleted = true
    end

    alias delete! delete    #:nodoc: obsolete

    def deleted?
      @deleted
    end

    def unique_id
      return @uid if @uid
      @pop.set_all_uids
      @uid
    end

    alias uidl unique_id

    def uid=(uid)   #:nodoc: internal use only
      @uid = uid
    end

  end   # class POPMail


  class POP3Command   #:nodoc: internal use only

    def initialize(sock)
      @socket = sock
      @error_occurred = false
      res = check_response(critical { recv_response() })
      @apop_stamp = res.slice(/<[!-~]+@[!-~]+>/)
    end

    attr_reader :socket

    def inspect
      "#<#{self.class} socket=#{@socket}>"
    end

    def auth(account, password)
      check_response_auth(critical {
        check_response_auth(get_response('USER %s', account))
        get_response('PASS %s', password)
      })
    end

    def apop(account, password)
      raise POPAuthenticationError, 'not APOP server; cannot login' \
                                                      unless @apop_stamp
      check_response_auth(critical {
        get_response('APOP %s %s',
                     account,
                     Digest::MD5.hexdigest(@apop_stamp + password))
      })
    end

    def list
      critical {
        getok 'LIST'
        list = []
        @socket.each_list_item do |line|
          m = /\A(\d+)[ \t]+(\d+)/.match(line) or
                  raise POPBadResponse, "bad response: #{line}"
          list.push  [m[1].to_i, m[2].to_i]
        end
        return list
      }
    end

    def stat
      res = check_response(critical { get_response('STAT') })
      m = /\A\+OK\s+(\d+)\s+(\d+)/.match(res) or
              raise POPBadResponse, "wrong response format: #{res}"
      [m[1].to_i, m[2].to_i]
    end

    def rset
      check_response(critical { get_response('RSET') })
    end

    def top(num, lines = 0, &block)
      critical {
        getok('TOP %d %d', num, lines)
        @socket.each_message_chunk(&block)
      }
    end

    def retr(num, &block)
      critical {
        getok('RETR %d', num)
        @socket.each_message_chunk(&block)
      }
    end

    def dele(num)
      check_response(critical { get_response('DELE %d', num) })
    end

    def uidl(num = nil)
      if num
        res = check_response(critical { get_response('UIDL %d', num) })
        return res.split(/ /)[1]
      else
        critical {
          getok('UIDL')
          table = {}
          @socket.each_list_item do |line|
            num, uid = line.split
            table[num.to_i] = uid
          end
          return table
        }
      end
    end

    def quit
      check_response(critical { get_response('QUIT') })
    end

    private

    def getok(fmt, *fargs)
      @socket.writeline sprintf(fmt, *fargs)
      check_response(recv_response())
    end

    def get_response(fmt, *fargs)
      @socket.writeline sprintf(fmt, *fargs)
      recv_response()
    end

    def recv_response
      @socket.readline
    end

    def check_response(res)
      raise POPError, res unless /\A\+OK/i =~ res
      res
    end

    def check_response_auth(res)
      raise POPAuthenticationError, res unless /\A\+OK/i =~ res
      res
    end

    def critical
      return '+OK dummy ok response' if @error_occurred
      begin
        return yield()
      rescue Exception
        @error_occurred = true
        raise
      end
    end

  end   # class POP3Command

end   # module Net
