

require "socket"
require "monitor"
require "digest/md5"
require "strscan"
begin
  require "openssl"
rescue LoadError
end

module Net

  class IMAP
    include MonitorMixin
    if defined?(OpenSSL::SSL)
      include OpenSSL
      include SSL
    end

    attr_reader :greeting

    attr_reader :responses

    attr_reader :response_handlers

    attr_accessor :client_thread

    SEEN = :Seen

    ANSWERED = :Answered

    FLAGGED = :Flagged

    DELETED = :Deleted

    DRAFT = :Draft

    RECENT = :Recent

    NOINFERIORS = :Noinferiors

    NOSELECT = :Noselect

    MARKED = :Marked

    UNMARKED = :Unmarked

    def self.debug
      return @@debug
    end

    def self.debug=(val)
      return @@debug = val
    end

    def self.max_flag_count
      return @@max_flag_count
    end

    def self.max_flag_count=(count)
      @@max_flag_count = count
    end

    def self.add_authenticator(auth_type, authenticator)
      @@authenticators[auth_type] = authenticator
    end

    def self.default_port
      return PORT
    end

    def self.default_tls_port
      return SSL_PORT
    end

    class << self
      alias default_imap_port default_port
      alias default_imaps_port default_tls_port
      alias default_ssl_port default_tls_port
    end

    def disconnect
      begin
        begin
          @sock.io.shutdown
        rescue NoMethodError
          @sock.shutdown
        end
      rescue Errno::ENOTCONN
      rescue Exception => e
        @receiver_thread.raise(e)
      end
      @receiver_thread.join
      synchronize do
        unless @sock.closed?
          @sock.close
        end
      end
      raise e if e
    end

    def disconnected?
      return @sock.closed?
    end

    def capability
      synchronize do
        send_command("CAPABILITY")
        return @responses.delete("CAPABILITY")[-1]
      end
    end

    def noop
      send_command("NOOP")
    end

    def logout
      send_command("LOGOUT")
    end

    def starttls(options = {}, verify = true)
      send_command("STARTTLS") do |resp|
        if resp.kind_of?(TaggedResponse) && resp.name == "OK"
          begin
            certs = options.to_str
            options = create_ssl_params(certs, verify)
          rescue NoMethodError
          end
          start_tls_session(options)
        end
      end
    end

    def authenticate(auth_type, *args)
      auth_type = auth_type.upcase
      unless @@authenticators.has_key?(auth_type)
        raise ArgumentError,
          format('unknown auth type - "%s"', auth_type)
      end
      authenticator = @@authenticators[auth_type].new(*args)
      send_command("AUTHENTICATE", auth_type) do |resp|
        if resp.instance_of?(ContinuationRequest)
          data = authenticator.process(resp.data.text.unpack("m")[0])
          s = [data].pack("m").gsub(/\n/, "")
          send_string_data(s)
          put_string(CRLF)
        end
      end
    end

    def login(user, password)
      send_command("LOGIN", user, password)
    end

    def select(mailbox)
      synchronize do
        @responses.clear
        send_command("SELECT", mailbox)
      end
    end

    def examine(mailbox)
      synchronize do
        @responses.clear
        send_command("EXAMINE", mailbox)
      end
    end

    def create(mailbox)
      send_command("CREATE", mailbox)
    end

    def delete(mailbox)
      send_command("DELETE", mailbox)
    end

    def rename(mailbox, newname)
      send_command("RENAME", mailbox, newname)
    end

    def subscribe(mailbox)
      send_command("SUBSCRIBE", mailbox)
    end

    def unsubscribe(mailbox)
      send_command("UNSUBSCRIBE", mailbox)
    end

    def list(refname, mailbox)
      synchronize do
        send_command("LIST", refname, mailbox)
        return @responses.delete("LIST")
      end
    end

    def xlist(refname, mailbox)
      synchronize do
        send_command("XLIST", refname, mailbox)
        return @responses.delete("XLIST")
      end
    end

    def getquotaroot(mailbox)
      synchronize do
        send_command("GETQUOTAROOT", mailbox)
        result = []
        result.concat(@responses.delete("QUOTAROOT"))
        result.concat(@responses.delete("QUOTA"))
        return result
      end
    end

    def getquota(mailbox)
      synchronize do
        send_command("GETQUOTA", mailbox)
        return @responses.delete("QUOTA")
      end
    end

    def setquota(mailbox, quota)
      if quota.nil?
        data = '()'
      else
        data = '(STORAGE ' + quota.to_s + ')'
      end
      send_command("SETQUOTA", mailbox, RawData.new(data))
    end

    def setacl(mailbox, user, rights)
      if rights.nil?
        send_command("SETACL", mailbox, user, "")
      else
        send_command("SETACL", mailbox, user, rights)
      end
    end

    def getacl(mailbox)
      synchronize do
        send_command("GETACL", mailbox)
        return @responses.delete("ACL")[-1]
      end
    end

    def lsub(refname, mailbox)
      synchronize do
        send_command("LSUB", refname, mailbox)
        return @responses.delete("LSUB")
      end
    end

    def status(mailbox, attr)
      synchronize do
        send_command("STATUS", mailbox, attr)
        return @responses.delete("STATUS")[-1].attr
      end
    end

    def append(mailbox, message, flags = nil, date_time = nil)
      args = []
      if flags
        args.push(flags)
      end
      args.push(date_time) if date_time
      args.push(Literal.new(message))
      send_command("APPEND", mailbox, *args)
    end

    def check
      send_command("CHECK")
    end

    def close
      send_command("CLOSE")
    end

    def expunge
      synchronize do
        send_command("EXPUNGE")
        return @responses.delete("EXPUNGE")
      end
    end

    def search(keys, charset = nil)
      return search_internal("SEARCH", keys, charset)
    end

    def uid_search(keys, charset = nil)
      return search_internal("UID SEARCH", keys, charset)
    end

    def fetch(set, attr)
      return fetch_internal("FETCH", set, attr)
    end

    def uid_fetch(set, attr)
      return fetch_internal("UID FETCH", set, attr)
    end

    def store(set, attr, flags)
      return store_internal("STORE", set, attr, flags)
    end

    def uid_store(set, attr, flags)
      return store_internal("UID STORE", set, attr, flags)
    end

    def copy(set, mailbox)
      copy_internal("COPY", set, mailbox)
    end

    def uid_copy(set, mailbox)
      copy_internal("UID COPY", set, mailbox)
    end

    def sort(sort_keys, search_keys, charset)
      return sort_internal("SORT", sort_keys, search_keys, charset)
    end

    def uid_sort(sort_keys, search_keys, charset)
      return sort_internal("UID SORT", sort_keys, search_keys, charset)
    end

    def add_response_handler(handler = Proc.new)
      @response_handlers.push(handler)
    end

    def remove_response_handler(handler)
      @response_handlers.delete(handler)
    end

    def thread(algorithm, search_keys, charset)
      return thread_internal("THREAD", algorithm, search_keys, charset)
    end

    def uid_thread(algorithm, search_keys, charset)
      return thread_internal("UID THREAD", algorithm, search_keys, charset)
    end

    def idle(&response_handler)
      raise LocalJumpError, "no block given" unless response_handler

      response = nil

      synchronize do
        tag = Thread.current[:net_imap_tag] = generate_tag
        put_string("#{tag} IDLE#{CRLF}")

        begin
          add_response_handler(response_handler)
          @idle_done_cond = new_cond
          @idle_done_cond.wait
          @idle_done_cond = nil
          if @receiver_thread_terminating
            raise Net::IMAP::Error, "connection closed"
          end
        ensure
          unless @receiver_thread_terminating
            remove_response_handler(response_handler)
            put_string("DONE#{CRLF}")
            response = get_tagged_response(tag, "IDLE")
          end
        end
      end

      return response
    end

    def idle_done
      synchronize do
        if @idle_done_cond.nil?
          raise Net::IMAP::Error, "not during IDLE"
        end
        @idle_done_cond.signal
      end
    end

    def self.decode_utf7(s)
      return s.gsub(/&([^-]+)?-/n) {
        if $1
          ($1.tr(",", "/") + "===").unpack("m")[0].encode(Encoding::UTF_8, Encoding::UTF_16BE)
        else
          "&"
        end
      }
    end

    def self.encode_utf7(s)
      return s.gsub(/(&)|[^\x20-\x7e]+/) {
        if $1
          "&-"
        else
          base64 = [$&.encode(Encoding::UTF_16BE)].pack("m")
          "&" + base64.delete("=\n").tr("/", ",") + "-"
        end
      }.force_encoding("ASCII-8BIT")
    end

    def self.format_date(time)
      return time.strftime('%d-%b-%Y')
    end

    def self.format_datetime(time)
      return time.strftime('%d-%b-%Y %H:%M %z')
    end

    private

    CRLF = "\r\n"      # :nodoc:
    PORT = 143         # :nodoc:
    SSL_PORT = 993   # :nodoc:

    @@debug = false
    @@authenticators = {}
    @@max_flag_count = 10000

    def initialize(host, port_or_options = {},
                   usessl = false, certs = nil, verify = true)
      super()
      @host = host
      begin
        options = port_or_options.to_hash
      rescue NoMethodError
        options = {}
        options[:port] = port_or_options
        if usessl
          options[:ssl] = create_ssl_params(certs, verify)
        end
      end
      @port = options[:port] || (options[:ssl] ? SSL_PORT : PORT)
      @tag_prefix = "RUBY"
      @tagno = 0
      @parser = ResponseParser.new
      @sock = TCPSocket.open(@host, @port)
      begin
        if options[:ssl]
          start_tls_session(options[:ssl])
          @usessl = true
        else
          @usessl = false
        end
        @responses = Hash.new([].freeze)
        @tagged_responses = {}
        @response_handlers = []
        @tagged_response_arrival = new_cond
        @continuation_request_arrival = new_cond
        @idle_done_cond = nil
        @logout_command_tag = nil
        @debug_output_bol = true
        @exception = nil

        @greeting = get_response
        if @greeting.nil?
          raise Error, "connection closed"
        end
        if @greeting.name == "BYE"
          raise ByeResponseError, @greeting
        end

        @client_thread = Thread.current
        @receiver_thread = Thread.start {
          begin
            receive_responses
          rescue Exception
          end
        }
        @receiver_thread_terminating = false
      rescue Exception
        @sock.close
        raise
      end
    end

    def receive_responses
      connection_closed = false
      until connection_closed
        synchronize do
          @exception = nil
        end
        begin
          resp = get_response
        rescue Exception => e
          synchronize do
            @sock.close
            @exception = e
          end
          break
        end
        unless resp
          synchronize do
            @exception = EOFError.new("end of file reached")
          end
          break
        end
        begin
          synchronize do
            case resp
            when TaggedResponse
              @tagged_responses[resp.tag] = resp
              @tagged_response_arrival.broadcast
              if resp.tag == @logout_command_tag
                return
              end
            when UntaggedResponse
              record_response(resp.name, resp.data)
              if resp.data.instance_of?(ResponseText) &&
                  (code = resp.data.code)
                record_response(code.name, code.data)
              end
              if resp.name == "BYE" && @logout_command_tag.nil?
                @sock.close
                @exception = ByeResponseError.new(resp)
                connection_closed = true
              end
            when ContinuationRequest
              @continuation_request_arrival.signal
            end
            @response_handlers.each do |handler|
              handler.call(resp)
            end
          end
        rescue Exception => e
          @exception = e
          synchronize do
            @tagged_response_arrival.broadcast
            @continuation_request_arrival.broadcast
          end
        end
      end
      synchronize do
        @receiver_thread_terminating = true
        @tagged_response_arrival.broadcast
        @continuation_request_arrival.broadcast
        if @idle_done_cond
          @idle_done_cond.signal
        end
      end
    end

    def get_tagged_response(tag, cmd)
      until @tagged_responses.key?(tag)
        raise @exception if @exception
        @tagged_response_arrival.wait
      end
      resp = @tagged_responses.delete(tag)
      case resp.name
      when /\A(?:NO)\z/ni
        raise NoResponseError, resp
      when /\A(?:BAD)\z/ni
        raise BadResponseError, resp
      else
        return resp
      end
    end

    def get_response
      buff = ""
      while true
        s = @sock.gets(CRLF)
        break unless s
        buff.concat(s)
        if /\{(\d+)\}\r\n/n =~ s
          s = @sock.read($1.to_i)
          buff.concat(s)
        else
          break
        end
      end
      return nil if buff.length == 0
      if @@debug
        $stderr.print(buff.gsub(/^/n, "S: "))
      end
      return @parser.parse(buff)
    end

    def record_response(name, data)
      unless @responses.has_key?(name)
        @responses[name] = []
      end
      @responses[name].push(data)
    end

    def send_command(cmd, *args, &block)
      synchronize do
        args.each do |i|
          validate_data(i)
        end
        tag = generate_tag
        put_string(tag + " " + cmd)
        args.each do |i|
          put_string(" ")
          send_data(i)
        end
        put_string(CRLF)
        if cmd == "LOGOUT"
          @logout_command_tag = tag
        end
        if block
          add_response_handler(block)
        end
        begin
          return get_tagged_response(tag, cmd)
        ensure
          if block
            remove_response_handler(block)
          end
        end
      end
    end

    def generate_tag
      @tagno += 1
      return format("%s%04d", @tag_prefix, @tagno)
    end

    def put_string(str)
      @sock.print(str)
      if @@debug
        if @debug_output_bol
          $stderr.print("C: ")
        end
        $stderr.print(str.gsub(/\n(?!\z)/n, "\nC: "))
        if /\r\n\z/n.match(str)
          @debug_output_bol = true
        else
          @debug_output_bol = false
        end
      end
    end

    def validate_data(data)
      case data
      when nil
      when String
      when Integer
        NumValidator.ensure_number(data)
      when Array
        data.each do |i|
          validate_data(i)
        end
      when Time
      when Symbol
      else
        data.validate
      end
    end

    def send_data(data)
      case data
      when nil
        put_string("NIL")
      when String
        send_string_data(data)
      when Integer
        send_number_data(data)
      when Array
        send_list_data(data)
      when Time
        send_time_data(data)
      when Symbol
        send_symbol_data(data)
      else
        data.send_data(self)
      end
    end

    def send_string_data(str)
      case str
      when ""
        put_string('""')
      when /[\x80-\xff\r\n]/n
        send_literal(str)
      when /[(){ \x00-\x1f\x7f%*"\\]/n
        send_quoted_string(str)
      else
        put_string(str)
      end
    end

    def send_quoted_string(str)
      put_string('"' + str.gsub(/["\\]/n, "\\\\\\&") + '"')
    end

    def send_literal(str)
      put_string("{" + str.bytesize.to_s + "}" + CRLF)
      @continuation_request_arrival.wait
      raise @exception if @exception
      put_string(str)
    end

    def send_number_data(num)
      put_string(num.to_s)
    end

    def send_list_data(list)
      put_string("(")
      first = true
      list.each do |i|
        if first
          first = false
        else
          put_string(" ")
        end
        send_data(i)
      end
      put_string(")")
    end

    DATE_MONTH = %w(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)

    def send_time_data(time)
      t = time.dup.gmtime
      s = format('"%2d-%3s-%4d %02d:%02d:%02d +0000"',
                 t.day, DATE_MONTH[t.month - 1], t.year,
                 t.hour, t.min, t.sec)
      put_string(s)
    end

    def send_symbol_data(symbol)
      put_string("\\" + symbol.to_s)
    end

    def search_internal(cmd, keys, charset)
      if keys.instance_of?(String)
        keys = [RawData.new(keys)]
      else
        normalize_searching_criteria(keys)
      end
      synchronize do
        if charset
          send_command(cmd, "CHARSET", charset, *keys)
        else
          send_command(cmd, *keys)
        end
        return @responses.delete("SEARCH")[-1]
      end
    end

    def fetch_internal(cmd, set, attr)
      case attr
      when String then
        attr = RawData.new(attr)
      when Array then
        attr = attr.map { |arg|
          arg.is_a?(String) ? RawData.new(arg) : arg
        }
      end

      synchronize do
        @responses.delete("FETCH")
        send_command(cmd, MessageSet.new(set), attr)
        return @responses.delete("FETCH")
      end
    end

    def store_internal(cmd, set, attr, flags)
      if attr.instance_of?(String)
        attr = RawData.new(attr)
      end
      synchronize do
        @responses.delete("FETCH")
        send_command(cmd, MessageSet.new(set), attr, flags)
        return @responses.delete("FETCH")
      end
    end

    def copy_internal(cmd, set, mailbox)
      send_command(cmd, MessageSet.new(set), mailbox)
    end

    def sort_internal(cmd, sort_keys, search_keys, charset)
      if search_keys.instance_of?(String)
        search_keys = [RawData.new(search_keys)]
      else
        normalize_searching_criteria(search_keys)
      end
      normalize_searching_criteria(search_keys)
      synchronize do
        send_command(cmd, sort_keys, charset, *search_keys)
        return @responses.delete("SORT")[-1]
      end
    end

    def thread_internal(cmd, algorithm, search_keys, charset)
      if search_keys.instance_of?(String)
        search_keys = [RawData.new(search_keys)]
      else
        normalize_searching_criteria(search_keys)
      end
      normalize_searching_criteria(search_keys)
      send_command(cmd, algorithm, charset, *search_keys)
      return @responses.delete("THREAD")[-1]
    end

    def normalize_searching_criteria(keys)
      keys.collect! do |i|
        case i
        when -1, Range, Array
          MessageSet.new(i)
        else
          i
        end
      end
    end

    def create_ssl_params(certs = nil, verify = true)
      params = {}
      if certs
        if File.file?(certs)
          params[:ca_file] = certs
        elsif File.directory?(certs)
          params[:ca_path] = certs
        end
      end
      if verify
        params[:verify_mode] = VERIFY_PEER
      else
        params[:verify_mode] = VERIFY_NONE
      end
      return params
    end

    def start_tls_session(params = {})
      unless defined?(OpenSSL::SSL)
        raise "SSL extension not installed"
      end
      if @sock.kind_of?(OpenSSL::SSL::SSLSocket)
        raise RuntimeError, "already using SSL"
      end
      begin
        params = params.to_hash
      rescue NoMethodError
        params = {}
      end
      context = SSLContext.new
      context.set_params(params)
      if defined?(VerifyCallbackProc)
        context.verify_callback = VerifyCallbackProc
      end
      @sock = SSLSocket.new(@sock, context)
      @sock.sync_close = true
      @sock.connect
      if context.verify_mode != VERIFY_NONE
        @sock.post_connection_check(@host)
      end
    end

    class RawData # :nodoc:
      def send_data(imap)
        #nodyna <send-2163> <SD EASY (private methods)>
        imap.send(:put_string, @data)
      end

      def validate
      end

      private

      def initialize(data)
        @data = data
      end
    end

    class Atom # :nodoc:
      def send_data(imap)
        #nodyna <send-2164> <SD EASY (private methods)>
        imap.send(:put_string, @data)
      end

      def validate
      end

      private

      def initialize(data)
        @data = data
      end
    end

    class QuotedString # :nodoc:
      def send_data(imap)
        #nodyna <send-2165> <SD EASY (private methods)>
        imap.send(:send_quoted_string, @data)
      end

      def validate
      end

      private

      def initialize(data)
        @data = data
      end
    end

    class Literal # :nodoc:
      def send_data(imap)
        #nodyna <send-2166> <SD EASY (private methods)>
        imap.send(:send_literal, @data)
      end

      def validate
      end

      private

      def initialize(data)
        @data = data
      end
    end

    class MessageSet # :nodoc:
      def send_data(imap)
        #nodyna <send-2167> <SD EASY (private methods)>
        imap.send(:put_string, format_internal(@data))
      end

      def validate
        validate_internal(@data)
      end

      private

      def initialize(data)
        @data = data
      end

      def format_internal(data)
        case data
        when "*"
          return data
        when Integer
          if data == -1
            return "*"
          else
            return data.to_s
          end
        when Range
          return format_internal(data.first) +
            ":" + format_internal(data.last)
        when Array
          return data.collect {|i| format_internal(i)}.join(",")
        when ThreadMember
          return data.seqno.to_s +
            ":" + data.children.collect {|i| format_internal(i).join(",")}
        end
      end

      def validate_internal(data)
        case data
        when "*"
        when Integer
          NumValidator.ensure_nz_number(data)
        when Range
        when Array
          data.each do |i|
            validate_internal(i)
          end
        when ThreadMember
          data.children.each do |i|
            validate_internal(i)
          end
        else
          raise DataFormatError, data.inspect
        end
      end
    end

    module NumValidator # :nodoc
      class << self
        def valid_number?(num)
          num >= 0 && num < 4294967296
        end

        def valid_nz_number?(num)
          num != 0 && valid_number?(num)
        end

        def ensure_number(num)
          return if valid_number?(num)

          msg = "number must be unsigned 32-bit integer: #{num}"
          raise DataFormatError, msg
        end

        def ensure_nz_number(num)
          return if valid_nz_number?(num)

          msg = "nz_number must be non-zero unsigned 32-bit integer: #{num}"
          raise DataFormatError, msg
        end
      end
    end

    ContinuationRequest = Struct.new(:data, :raw_data)

    UntaggedResponse = Struct.new(:name, :data, :raw_data)

    TaggedResponse = Struct.new(:tag, :name, :data, :raw_data)

    ResponseText = Struct.new(:code, :text)

    ResponseCode = Struct.new(:name, :data)

    MailboxList = Struct.new(:attr, :delim, :name)

    MailboxQuota = Struct.new(:mailbox, :usage, :quota)

    MailboxQuotaRoot = Struct.new(:mailbox, :quotaroots)

    MailboxACLItem = Struct.new(:user, :rights, :mailbox)

    StatusData = Struct.new(:mailbox, :attr)

    FetchData = Struct.new(:seqno, :attr)

    Envelope = Struct.new(:date, :subject, :from, :sender, :reply_to,
                          :to, :cc, :bcc, :in_reply_to, :message_id)

    Address = Struct.new(:name, :route, :mailbox, :host)

    ContentDisposition = Struct.new(:dsp_type, :param)

    ThreadMember = Struct.new(:seqno, :children)

    class BodyTypeBasic < Struct.new(:media_type, :subtype,
                                     :param, :content_id,
                                     :description, :encoding, :size,
                                     :md5, :disposition, :language,
                                     :extension)
      def multipart?
        return false
      end

      def media_subtype
        $stderr.printf("warning: media_subtype is obsolete.\n")
        $stderr.printf("         use subtype instead.\n")
        return subtype
      end
    end

    class BodyTypeText < Struct.new(:media_type, :subtype,
                                    :param, :content_id,
                                    :description, :encoding, :size,
                                    :lines,
                                    :md5, :disposition, :language,
                                    :extension)
      def multipart?
        return false
      end

      def media_subtype
        $stderr.printf("warning: media_subtype is obsolete.\n")
        $stderr.printf("         use subtype instead.\n")
        return subtype
      end
    end

    class BodyTypeMessage < Struct.new(:media_type, :subtype,
                                       :param, :content_id,
                                       :description, :encoding, :size,
                                       :envelope, :body, :lines,
                                       :md5, :disposition, :language,
                                       :extension)
      def multipart?
        return false
      end

      def media_subtype
        $stderr.printf("warning: media_subtype is obsolete.\n")
        $stderr.printf("         use subtype instead.\n")
        return subtype
      end
    end

    class BodyTypeAttachment < Struct.new(:media_type, :subtype,
                                          :param)
      def multipart?
        return false
      end
    end

    class BodyTypeMultipart < Struct.new(:media_type, :subtype,
                                         :parts,
                                         :param, :disposition, :language,
                                         :extension)
      def multipart?
        return true
      end

      def media_subtype
        $stderr.printf("warning: media_subtype is obsolete.\n")
        $stderr.printf("         use subtype instead.\n")
        return subtype
      end
    end

    class BodyTypeExtension < Struct.new(:media_type, :subtype,
                                         :params, :content_id,
                                         :description, :encoding, :size)
      def multipart?
        return false
      end
    end

    class ResponseParser # :nodoc:
      def initialize
        @str = nil
        @pos = nil
        @lex_state = nil
        @token = nil
        @flag_symbols = {}
      end

      def parse(str)
        @str = str
        @pos = 0
        @lex_state = EXPR_BEG
        @token = nil
        return response
      end

      private

      EXPR_BEG          = :EXPR_BEG
      EXPR_DATA         = :EXPR_DATA
      EXPR_TEXT         = :EXPR_TEXT
      EXPR_RTEXT        = :EXPR_RTEXT
      EXPR_CTEXT        = :EXPR_CTEXT

      T_SPACE   = :SPACE
      T_NIL     = :NIL
      T_NUMBER  = :NUMBER
      T_ATOM    = :ATOM
      T_QUOTED  = :QUOTED
      T_LPAR    = :LPAR
      T_RPAR    = :RPAR
      T_BSLASH  = :BSLASH
      T_STAR    = :STAR
      T_LBRA    = :LBRA
      T_RBRA    = :RBRA
      T_LITERAL = :LITERAL
      T_PLUS    = :PLUS
      T_PERCENT = :PERCENT
      T_CRLF    = :CRLF
      T_EOF     = :EOF
      T_TEXT    = :TEXT

      BEG_REGEXP = /\G(?:\
(?# 1:  SPACE   )( +)|\
(?# 2:  NIL     )(NIL)(?=[\x80-\xff(){ \x00-\x1f\x7f%*"\\\[\]+])|\
(?# 3:  NUMBER  )(\d+)(?=[\x80-\xff(){ \x00-\x1f\x7f%*"\\\[\]+])|\
(?# 4:  ATOM    )([^\x80-\xff(){ \x00-\x1f\x7f%*"\\\[\]+]+)|\
(?# 5:  QUOTED  )"((?:[^\x00\r\n"\\]|\\["\\])*)"|\
(?# 6:  LPAR    )(\()|\
(?# 7:  RPAR    )(\))|\
(?# 8:  BSLASH  )(\\)|\
(?# 9:  STAR    )(\*)|\
(?# 10: LBRA    )(\[)|\
(?# 11: RBRA    )(\])|\
(?# 12: LITERAL )\{(\d+)\}\r\n|\
(?# 13: PLUS    )(\+)|\
(?# 14: PERCENT )(%)|\
(?# 15: CRLF    )(\r\n)|\
(?# 16: EOF     )(\z))/ni

      DATA_REGEXP = /\G(?:\
(?# 1:  SPACE   )( )|\
(?# 2:  NIL     )(NIL)|\
(?# 3:  NUMBER  )(\d+)|\
(?# 4:  QUOTED  )"((?:[^\x00\r\n"\\]|\\["\\])*)"|\
(?# 5:  LITERAL )\{(\d+)\}\r\n|\
(?# 6:  LPAR    )(\()|\
(?# 7:  RPAR    )(\)))/ni

      TEXT_REGEXP = /\G(?:\
(?# 1:  TEXT    )([^\x00\r\n]*))/ni

      RTEXT_REGEXP = /\G(?:\
(?# 1:  LBRA    )(\[)|\
(?# 2:  TEXT    )([^\x00\r\n]*))/ni

      CTEXT_REGEXP = /\G(?:\
(?# 1:  TEXT    )([^\x00\r\n\]]*))/ni

      Token = Struct.new(:symbol, :value)

      def response
        token = lookahead
        case token.symbol
        when T_PLUS
          result = continue_req
        when T_STAR
          result = response_untagged
        else
          result = response_tagged
        end
        match(T_CRLF)
        match(T_EOF)
        return result
      end

      def continue_req
        match(T_PLUS)
        match(T_SPACE)
        return ContinuationRequest.new(resp_text, @str)
      end

      def response_untagged
        match(T_STAR)
        match(T_SPACE)
        token = lookahead
        if token.symbol == T_NUMBER
          return numeric_response
        elsif token.symbol == T_ATOM
          case token.value
          when /\A(?:OK|NO|BAD|BYE|PREAUTH)\z/ni
            return response_cond
          when /\A(?:FLAGS)\z/ni
            return flags_response
          when /\A(?:LIST|LSUB|XLIST)\z/ni
            return list_response
          when /\A(?:QUOTA)\z/ni
            return getquota_response
          when /\A(?:QUOTAROOT)\z/ni
            return getquotaroot_response
          when /\A(?:ACL)\z/ni
            return getacl_response
          when /\A(?:SEARCH|SORT)\z/ni
            return search_response
          when /\A(?:THREAD)\z/ni
            return thread_response
          when /\A(?:STATUS)\z/ni
            return status_response
          when /\A(?:CAPABILITY)\z/ni
            return capability_response
          else
            return text_response
          end
        else
          parse_error("unexpected token %s", token.symbol)
        end
      end

      def response_tagged
        tag = atom
        match(T_SPACE)
        token = match(T_ATOM)
        name = token.value.upcase
        match(T_SPACE)
        return TaggedResponse.new(tag, name, resp_text, @str)
      end

      def response_cond
        token = match(T_ATOM)
        name = token.value.upcase
        match(T_SPACE)
        return UntaggedResponse.new(name, resp_text, @str)
      end

      def numeric_response
        n = number
        match(T_SPACE)
        token = match(T_ATOM)
        name = token.value.upcase
        case name
        when "EXISTS", "RECENT", "EXPUNGE"
          return UntaggedResponse.new(name, n, @str)
        when "FETCH"
          shift_token
          match(T_SPACE)
          data = FetchData.new(n, msg_att(n))
          return UntaggedResponse.new(name, data, @str)
        end
      end

      def msg_att(n)
        match(T_LPAR)
        attr = {}
        while true
          token = lookahead
          case token.symbol
          when T_RPAR
            shift_token
            break
          when T_SPACE
            shift_token
            next
          end
          case token.value
          when /\A(?:ENVELOPE)\z/ni
            name, val = envelope_data
          when /\A(?:FLAGS)\z/ni
            name, val = flags_data
          when /\A(?:INTERNALDATE)\z/ni
            name, val = internaldate_data
          when /\A(?:RFC822(?:\.HEADER|\.TEXT)?)\z/ni
            name, val = rfc822_text
          when /\A(?:RFC822\.SIZE)\z/ni
            name, val = rfc822_size
          when /\A(?:BODY(?:STRUCTURE)?)\z/ni
            name, val = body_data
          when /\A(?:UID)\z/ni
            name, val = uid_data
          else
            parse_error("unknown attribute `%s' for {%d}", token.value, n)
          end
          attr[name] = val
        end
        return attr
      end

      def envelope_data
        token = match(T_ATOM)
        name = token.value.upcase
        match(T_SPACE)
        return name, envelope
      end

      def envelope
        @lex_state = EXPR_DATA
        token = lookahead
        if token.symbol == T_NIL
          shift_token
          result = nil
        else
          match(T_LPAR)
          date = nstring
          match(T_SPACE)
          subject = nstring
          match(T_SPACE)
          from = address_list
          match(T_SPACE)
          sender = address_list
          match(T_SPACE)
          reply_to = address_list
          match(T_SPACE)
          to = address_list
          match(T_SPACE)
          cc = address_list
          match(T_SPACE)
          bcc = address_list
          match(T_SPACE)
          in_reply_to = nstring
          match(T_SPACE)
          message_id = nstring
          match(T_RPAR)
          result = Envelope.new(date, subject, from, sender, reply_to,
                                to, cc, bcc, in_reply_to, message_id)
        end
        @lex_state = EXPR_BEG
        return result
      end

      def flags_data
        token = match(T_ATOM)
        name = token.value.upcase
        match(T_SPACE)
        return name, flag_list
      end

      def internaldate_data
        token = match(T_ATOM)
        name = token.value.upcase
        match(T_SPACE)
        token = match(T_QUOTED)
        return name, token.value
      end

      def rfc822_text
        token = match(T_ATOM)
        name = token.value.upcase
        token = lookahead
        if token.symbol == T_LBRA
          shift_token
          match(T_RBRA)
        end
        match(T_SPACE)
        return name, nstring
      end

      def rfc822_size
        token = match(T_ATOM)
        name = token.value.upcase
        match(T_SPACE)
        return name, number
      end

      def body_data
        token = match(T_ATOM)
        name = token.value.upcase
        token = lookahead
        if token.symbol == T_SPACE
          shift_token
          return name, body
        end
        name.concat(section)
        token = lookahead
        if token.symbol == T_ATOM
          name.concat(token.value)
          shift_token
        end
        match(T_SPACE)
        data = nstring
        return name, data
      end

      def body
        @lex_state = EXPR_DATA
        token = lookahead
        if token.symbol == T_NIL
          shift_token
          result = nil
        else
          match(T_LPAR)
          token = lookahead
          if token.symbol == T_LPAR
            result = body_type_mpart
          else
            result = body_type_1part
          end
          match(T_RPAR)
        end
        @lex_state = EXPR_BEG
        return result
      end

      def body_type_1part
        token = lookahead
        case token.value
        when /\A(?:TEXT)\z/ni
          return body_type_text
        when /\A(?:MESSAGE)\z/ni
          return body_type_msg
        when /\A(?:ATTACHMENT)\z/ni
          return body_type_attachment
        when /\A(?:MIXED)\z/ni
          return body_type_mixed
        else
          return body_type_basic
        end
      end

      def body_type_basic
        mtype, msubtype = media_type
        token = lookahead
        if token.symbol == T_RPAR
          return BodyTypeBasic.new(mtype, msubtype)
        end
        match(T_SPACE)
        param, content_id, desc, enc, size = body_fields
        md5, disposition, language, extension = body_ext_1part
        return BodyTypeBasic.new(mtype, msubtype,
                                 param, content_id,
                                 desc, enc, size,
                                 md5, disposition, language, extension)
      end

      def body_type_text
        mtype, msubtype = media_type
        match(T_SPACE)
        param, content_id, desc, enc, size = body_fields
        match(T_SPACE)
        lines = number
        md5, disposition, language, extension = body_ext_1part
        return BodyTypeText.new(mtype, msubtype,
                                param, content_id,
                                desc, enc, size,
                                lines,
                                md5, disposition, language, extension)
      end

      def body_type_msg
        mtype, msubtype = media_type
        match(T_SPACE)
        param, content_id, desc, enc, size = body_fields

        token = lookahead
        if token.symbol == T_RPAR

          if msubtype == "RFC822"
            return BodyTypeMessage.new(mtype, msubtype, param, content_id,
                                       desc, enc, size, nil, nil, nil, nil,
                                       nil, nil, nil)
          else
            return BodyTypeExtension.new(mtype, msubtype,
                                         param, content_id,
                                         desc, enc, size)
          end
        end

        match(T_SPACE)
        env = envelope
        match(T_SPACE)
        b = body
        match(T_SPACE)
        lines = number
        md5, disposition, language, extension = body_ext_1part
        return BodyTypeMessage.new(mtype, msubtype,
                                   param, content_id,
                                   desc, enc, size,
                                   env, b, lines,
                                   md5, disposition, language, extension)
      end

      def body_type_attachment
        mtype = case_insensitive_string
        match(T_SPACE)
        param = body_fld_param
        return BodyTypeAttachment.new(mtype, nil, param)
      end

      def body_type_mixed
        mtype = "MULTIPART"
        msubtype = case_insensitive_string
        param, disposition, language, extension = body_ext_mpart
        return BodyTypeBasic.new(mtype, msubtype, param, nil, nil, nil, nil, nil, disposition, language, extension)
      end

      def body_type_mpart
        parts = []
        while true
          token = lookahead
          if token.symbol == T_SPACE
            shift_token
            break
          end
          parts.push(body)
        end
        mtype = "MULTIPART"
        msubtype = case_insensitive_string
        param, disposition, language, extension = body_ext_mpart
        return BodyTypeMultipart.new(mtype, msubtype, parts,
                                     param, disposition, language,
                                     extension)
      end

      def media_type
        mtype = case_insensitive_string
        token = lookahead
        if token.symbol != T_SPACE
          return mtype, nil
        end
        match(T_SPACE)
        msubtype = case_insensitive_string
        return mtype, msubtype
      end

      def body_fields
        param = body_fld_param
        match(T_SPACE)
        content_id = nstring
        match(T_SPACE)
        desc = nstring
        match(T_SPACE)
        enc = case_insensitive_string
        match(T_SPACE)
        size = number
        return param, content_id, desc, enc, size
      end

      def body_fld_param
        token = lookahead
        if token.symbol == T_NIL
          shift_token
          return nil
        end
        match(T_LPAR)
        param = {}
        while true
          token = lookahead
          case token.symbol
          when T_RPAR
            shift_token
            break
          when T_SPACE
            shift_token
          end
          name = case_insensitive_string
          match(T_SPACE)
          val = string
          param[name] = val
        end
        return param
      end

      def body_ext_1part
        token = lookahead
        if token.symbol == T_SPACE
          shift_token
        else
          return nil
        end
        md5 = nstring

        token = lookahead
        if token.symbol == T_SPACE
          shift_token
        else
          return md5
        end
        disposition = body_fld_dsp

        token = lookahead
        if token.symbol == T_SPACE
          shift_token
        else
          return md5, disposition
        end
        language = body_fld_lang

        token = lookahead
        if token.symbol == T_SPACE
          shift_token
        else
          return md5, disposition, language
        end

        extension = body_extensions
        return md5, disposition, language, extension
      end

      def body_ext_mpart
        token = lookahead
        if token.symbol == T_SPACE
          shift_token
        else
          return nil
        end
        param = body_fld_param

        token = lookahead
        if token.symbol == T_SPACE
          shift_token
        else
          return param
        end
        disposition = body_fld_dsp

        token = lookahead
        if token.symbol == T_SPACE
          shift_token
        else
          return param, disposition
        end
        language = body_fld_lang

        token = lookahead
        if token.symbol == T_SPACE
          shift_token
        else
          return param, disposition, language
        end

        extension = body_extensions
        return param, disposition, language, extension
      end

      def body_fld_dsp
        token = lookahead
        if token.symbol == T_NIL
          shift_token
          return nil
        end
        match(T_LPAR)
        dsp_type = case_insensitive_string
        match(T_SPACE)
        param = body_fld_param
        match(T_RPAR)
        return ContentDisposition.new(dsp_type, param)
      end

      def body_fld_lang
        token = lookahead
        if token.symbol == T_LPAR
          shift_token
          result = []
          while true
            token = lookahead
            case token.symbol
            when T_RPAR
              shift_token
              return result
            when T_SPACE
              shift_token
            end
            result.push(case_insensitive_string)
          end
        else
          lang = nstring
          if lang
            return lang.upcase
          else
            return lang
          end
        end
      end

      def body_extensions
        result = []
        while true
          token = lookahead
          case token.symbol
          when T_RPAR
            return result
          when T_SPACE
            shift_token
          end
          result.push(body_extension)
        end
      end

      def body_extension
        token = lookahead
        case token.symbol
        when T_LPAR
          shift_token
          result = body_extensions
          match(T_RPAR)
          return result
        when T_NUMBER
          return number
        else
          return nstring
        end
      end

      def section
        str = ""
        token = match(T_LBRA)
        str.concat(token.value)
        token = match(T_ATOM, T_NUMBER, T_RBRA)
        if token.symbol == T_RBRA
          str.concat(token.value)
          return str
        end
        str.concat(token.value)
        token = lookahead
        if token.symbol == T_SPACE
          shift_token
          str.concat(token.value)
          token = match(T_LPAR)
          str.concat(token.value)
          while true
            token = lookahead
            case token.symbol
            when T_RPAR
              str.concat(token.value)
              shift_token
              break
            when T_SPACE
              shift_token
              str.concat(token.value)
            end
            str.concat(format_string(astring))
          end
        end
        token = match(T_RBRA)
        str.concat(token.value)
        return str
      end

      def format_string(str)
        case str
        when ""
          return '""'
        when /[\x80-\xff\r\n]/n
          return "{" + str.bytesize.to_s + "}" + CRLF + str
        when /[(){ \x00-\x1f\x7f%*"\\]/n
          return '"' + str.gsub(/["\\]/n, "\\\\\\&") + '"'
        else
          return str
        end
      end

      def uid_data
        token = match(T_ATOM)
        name = token.value.upcase
        match(T_SPACE)
        return name, number
      end

      def text_response
        token = match(T_ATOM)
        name = token.value.upcase
        match(T_SPACE)
        @lex_state = EXPR_TEXT
        token = match(T_TEXT)
        @lex_state = EXPR_BEG
        return UntaggedResponse.new(name, token.value)
      end

      def flags_response
        token = match(T_ATOM)
        name = token.value.upcase
        match(T_SPACE)
        return UntaggedResponse.new(name, flag_list, @str)
      end

      def list_response
        token = match(T_ATOM)
        name = token.value.upcase
        match(T_SPACE)
        return UntaggedResponse.new(name, mailbox_list, @str)
      end

      def mailbox_list
        attr = flag_list
        match(T_SPACE)
        token = match(T_QUOTED, T_NIL)
        if token.symbol == T_NIL
          delim = nil
        else
          delim = token.value
        end
        match(T_SPACE)
        name = astring
        return MailboxList.new(attr, delim, name)
      end

      def getquota_response
        token = match(T_ATOM)
        name = token.value.upcase
        match(T_SPACE)
        mailbox = astring
        match(T_SPACE)
        match(T_LPAR)
        token = lookahead
        case token.symbol
        when T_RPAR
          shift_token
          data = MailboxQuota.new(mailbox, nil, nil)
          return UntaggedResponse.new(name, data, @str)
        when T_ATOM
          shift_token
          match(T_SPACE)
          token = match(T_NUMBER)
          usage = token.value
          match(T_SPACE)
          token = match(T_NUMBER)
          quota = token.value
          match(T_RPAR)
          data = MailboxQuota.new(mailbox, usage, quota)
          return UntaggedResponse.new(name, data, @str)
        else
          parse_error("unexpected token %s", token.symbol)
        end
      end

      def getquotaroot_response
        token = match(T_ATOM)
        name = token.value.upcase
        match(T_SPACE)
        mailbox = astring
        quotaroots = []
        while true
          token = lookahead
          break unless token.symbol == T_SPACE
          shift_token
          quotaroots.push(astring)
        end
        data = MailboxQuotaRoot.new(mailbox, quotaroots)
        return UntaggedResponse.new(name, data, @str)
      end

      def getacl_response
        token = match(T_ATOM)
        name = token.value.upcase
        match(T_SPACE)
        mailbox = astring
        data = []
        token = lookahead
        if token.symbol == T_SPACE
          shift_token
          while true
            token = lookahead
            case token.symbol
            when T_CRLF
              break
            when T_SPACE
              shift_token
            end
            user = astring
            match(T_SPACE)
            rights = astring
            data.push(MailboxACLItem.new(user, rights, mailbox))
          end
        end
        return UntaggedResponse.new(name, data, @str)
      end

      def search_response
        token = match(T_ATOM)
        name = token.value.upcase
        token = lookahead
        if token.symbol == T_SPACE
          shift_token
          data = []
          while true
            token = lookahead
            case token.symbol
            when T_CRLF
              break
            when T_SPACE
              shift_token
            when T_NUMBER
              data.push(number)
            when T_LPAR
              shift_token
              match(T_ATOM)
              match(T_SPACE)
              match(T_NUMBER)
              match(T_RPAR)
            end
          end
        else
          data = []
        end
        return UntaggedResponse.new(name, data, @str)
      end

      def thread_response
        token = match(T_ATOM)
        name = token.value.upcase
        token = lookahead

        if token.symbol == T_SPACE
          threads = []

          while true
            shift_token
            token = lookahead

            case token.symbol
            when T_LPAR
              threads << thread_branch(token)
            when T_CRLF
              break
            end
          end
        else
          threads = []
        end

        return UntaggedResponse.new(name, threads, @str)
      end

      def thread_branch(token)
        rootmember = nil
        lastmember = nil

        while true
          shift_token    # ignore first T_LPAR
          token = lookahead

          case token.symbol
          when T_NUMBER
            newmember = ThreadMember.new(number, [])
            if rootmember.nil?
              rootmember = newmember
            else
              lastmember.children << newmember
            end
            lastmember = newmember
          when T_SPACE
          when T_LPAR
            if rootmember.nil?
              lastmember = rootmember = ThreadMember.new(nil, [])
            end

            lastmember.children << thread_branch(token)
          when T_RPAR
            break
          end
        end

        return rootmember
      end

      def status_response
        token = match(T_ATOM)
        name = token.value.upcase
        match(T_SPACE)
        mailbox = astring
        match(T_SPACE)
        match(T_LPAR)
        attr = {}
        while true
          token = lookahead
          case token.symbol
          when T_RPAR
            shift_token
            break
          when T_SPACE
            shift_token
          end
          token = match(T_ATOM)
          key = token.value.upcase
          match(T_SPACE)
          val = number
          attr[key] = val
        end
        data = StatusData.new(mailbox, attr)
        return UntaggedResponse.new(name, data, @str)
      end

      def capability_response
        token = match(T_ATOM)
        name = token.value.upcase
        match(T_SPACE)
        data = []
        while true
          token = lookahead
          case token.symbol
          when T_CRLF
            break
          when T_SPACE
            shift_token
            next
          end
          data.push(atom.upcase)
        end
        return UntaggedResponse.new(name, data, @str)
      end

      def resp_text
        @lex_state = EXPR_RTEXT
        token = lookahead
        if token.symbol == T_LBRA
          code = resp_text_code
        else
          code = nil
        end
        token = match(T_TEXT)
        @lex_state = EXPR_BEG
        return ResponseText.new(code, token.value)
      end

      def resp_text_code
        @lex_state = EXPR_BEG
        match(T_LBRA)
        token = match(T_ATOM)
        name = token.value.upcase
        case name
        when /\A(?:ALERT|PARSE|READ-ONLY|READ-WRITE|TRYCREATE|NOMODSEQ)\z/n
          result = ResponseCode.new(name, nil)
        when /\A(?:PERMANENTFLAGS)\z/n
          match(T_SPACE)
          result = ResponseCode.new(name, flag_list)
        when /\A(?:UIDVALIDITY|UIDNEXT|UNSEEN)\z/n
          match(T_SPACE)
          result = ResponseCode.new(name, number)
        else
          token = lookahead
          if token.symbol == T_SPACE
            shift_token
            @lex_state = EXPR_CTEXT
            token = match(T_TEXT)
            @lex_state = EXPR_BEG
            result = ResponseCode.new(name, token.value)
          else
            result = ResponseCode.new(name, nil)
          end
        end
        match(T_RBRA)
        @lex_state = EXPR_RTEXT
        return result
      end

      def address_list
        token = lookahead
        if token.symbol == T_NIL
          shift_token
          return nil
        else
          result = []
          match(T_LPAR)
          while true
            token = lookahead
            case token.symbol
            when T_RPAR
              shift_token
              break
            when T_SPACE
              shift_token
            end
            result.push(address)
          end
          return result
        end
      end

      ADDRESS_REGEXP = /\G\
(?# 1: NAME     )(?:NIL|"((?:[^\x80-\xff\x00\r\n"\\]|\\["\\])*)") \
(?# 2: ROUTE    )(?:NIL|"((?:[^\x80-\xff\x00\r\n"\\]|\\["\\])*)") \
(?# 3: MAILBOX  )(?:NIL|"((?:[^\x80-\xff\x00\r\n"\\]|\\["\\])*)") \
(?# 4: HOST     )(?:NIL|"((?:[^\x80-\xff\x00\r\n"\\]|\\["\\])*)")\
\)/ni

      def address
        match(T_LPAR)
        if @str.index(ADDRESS_REGEXP, @pos)
          @pos = $~.end(0)
          name = $1
          route = $2
          mailbox = $3
          host = $4
          for s in [name, route, mailbox, host]
            if s
              s.gsub!(/\\(["\\])/n, "\\1")
            end
          end
        else
          name = nstring
          match(T_SPACE)
          route = nstring
          match(T_SPACE)
          mailbox = nstring
          match(T_SPACE)
          host = nstring
          match(T_RPAR)
        end
        return Address.new(name, route, mailbox, host)
      end

      FLAG_REGEXP = /\
(?# FLAG        )\\([^\x80-\xff(){ \x00-\x1f\x7f%"\\]+)|\
(?# ATOM        )([^\x80-\xff(){ \x00-\x1f\x7f%*"\\]+)/n

      def flag_list
        if @str.index(/\(([^)]*)\)/ni, @pos)
          @pos = $~.end(0)
          return $1.scan(FLAG_REGEXP).collect { |flag, atom|
            if atom
              atom
            else
              symbol = flag.capitalize.untaint.intern
              @flag_symbols[symbol] = true
              if @flag_symbols.length > IMAP.max_flag_count
                raise FlagCountError, "number of flag symbols exceeded"
              end
              symbol
            end
          }
        else
          parse_error("invalid flag list")
        end
      end

      def nstring
        token = lookahead
        if token.symbol == T_NIL
          shift_token
          return nil
        else
          return string
        end
      end

      def astring
        token = lookahead
        if string_token?(token)
          return string
        else
          return atom
        end
      end

      def string
        token = lookahead
        if token.symbol == T_NIL
          shift_token
          return nil
        end
        token = match(T_QUOTED, T_LITERAL)
        return token.value
      end

      STRING_TOKENS = [T_QUOTED, T_LITERAL, T_NIL]

      def string_token?(token)
        return STRING_TOKENS.include?(token.symbol)
      end

      def case_insensitive_string
        token = lookahead
        if token.symbol == T_NIL
          shift_token
          return nil
        end
        token = match(T_QUOTED, T_LITERAL)
        return token.value.upcase
      end

      def atom
        result = ""
        while true
          token = lookahead
          if atom_token?(token)
            result.concat(token.value)
            shift_token
          else
            if result.empty?
              parse_error("unexpected token %s", token.symbol)
            else
              return result
            end
          end
        end
      end

      ATOM_TOKENS = [
        T_ATOM,
        T_NUMBER,
        T_NIL,
        T_LBRA,
        T_RBRA,
        T_PLUS
      ]

      def atom_token?(token)
        return ATOM_TOKENS.include?(token.symbol)
      end

      def number
        token = lookahead
        if token.symbol == T_NIL
          shift_token
          return nil
        end
        token = match(T_NUMBER)
        return token.value.to_i
      end

      def nil_atom
        match(T_NIL)
        return nil
      end

      def match(*args)
        token = lookahead
        unless args.include?(token.symbol)
          parse_error('unexpected token %s (expected %s)',
                      token.symbol.id2name,
                      args.collect {|i| i.id2name}.join(" or "))
        end
        shift_token
        return token
      end

      def lookahead
        unless @token
          @token = next_token
        end
        return @token
      end

      def shift_token
        @token = nil
      end

      def next_token
        case @lex_state
        when EXPR_BEG
          if @str.index(BEG_REGEXP, @pos)
            @pos = $~.end(0)
            if $1
              return Token.new(T_SPACE, $+)
            elsif $2
              return Token.new(T_NIL, $+)
            elsif $3
              return Token.new(T_NUMBER, $+)
            elsif $4
              return Token.new(T_ATOM, $+)
            elsif $5
              return Token.new(T_QUOTED,
                               $+.gsub(/\\(["\\])/n, "\\1"))
            elsif $6
              return Token.new(T_LPAR, $+)
            elsif $7
              return Token.new(T_RPAR, $+)
            elsif $8
              return Token.new(T_BSLASH, $+)
            elsif $9
              return Token.new(T_STAR, $+)
            elsif $10
              return Token.new(T_LBRA, $+)
            elsif $11
              return Token.new(T_RBRA, $+)
            elsif $12
              len = $+.to_i
              val = @str[@pos, len]
              @pos += len
              return Token.new(T_LITERAL, val)
            elsif $13
              return Token.new(T_PLUS, $+)
            elsif $14
              return Token.new(T_PERCENT, $+)
            elsif $15
              return Token.new(T_CRLF, $+)
            elsif $16
              return Token.new(T_EOF, $+)
            else
              parse_error("[Net::IMAP BUG] BEG_REGEXP is invalid")
            end
          else
            @str.index(/\S*/n, @pos)
            parse_error("unknown token - %s", $&.dump)
          end
        when EXPR_DATA
          if @str.index(DATA_REGEXP, @pos)
            @pos = $~.end(0)
            if $1
              return Token.new(T_SPACE, $+)
            elsif $2
              return Token.new(T_NIL, $+)
            elsif $3
              return Token.new(T_NUMBER, $+)
            elsif $4
              return Token.new(T_QUOTED,
                               $+.gsub(/\\(["\\])/n, "\\1"))
            elsif $5
              len = $+.to_i
              val = @str[@pos, len]
              @pos += len
              return Token.new(T_LITERAL, val)
            elsif $6
              return Token.new(T_LPAR, $+)
            elsif $7
              return Token.new(T_RPAR, $+)
            else
              parse_error("[Net::IMAP BUG] DATA_REGEXP is invalid")
            end
          else
            @str.index(/\S*/n, @pos)
            parse_error("unknown token - %s", $&.dump)
          end
        when EXPR_TEXT
          if @str.index(TEXT_REGEXP, @pos)
            @pos = $~.end(0)
            if $1
              return Token.new(T_TEXT, $+)
            else
              parse_error("[Net::IMAP BUG] TEXT_REGEXP is invalid")
            end
          else
            @str.index(/\S*/n, @pos)
            parse_error("unknown token - %s", $&.dump)
          end
        when EXPR_RTEXT
          if @str.index(RTEXT_REGEXP, @pos)
            @pos = $~.end(0)
            if $1
              return Token.new(T_LBRA, $+)
            elsif $2
              return Token.new(T_TEXT, $+)
            else
              parse_error("[Net::IMAP BUG] RTEXT_REGEXP is invalid")
            end
          else
            @str.index(/\S*/n, @pos)
            parse_error("unknown token - %s", $&.dump)
          end
        when EXPR_CTEXT
          if @str.index(CTEXT_REGEXP, @pos)
            @pos = $~.end(0)
            if $1
              return Token.new(T_TEXT, $+)
            else
              parse_error("[Net::IMAP BUG] CTEXT_REGEXP is invalid")
            end
          else
            @str.index(/\S*/n, @pos) #/
            parse_error("unknown token - %s", $&.dump)
          end
        else
          parse_error("invalid @lex_state - %s", @lex_state.inspect)
        end
      end

      def parse_error(fmt, *args)
        if IMAP.debug
          $stderr.printf("@str: %s\n", @str.dump)
          $stderr.printf("@pos: %d\n", @pos)
          $stderr.printf("@lex_state: %s\n", @lex_state)
          if @token
            $stderr.printf("@token.symbol: %s\n", @token.symbol)
            $stderr.printf("@token.value: %s\n", @token.value.inspect)
          end
        end
        raise ResponseParseError, format(fmt, *args)
      end
    end

    class LoginAuthenticator
      def process(data)
        case @state
        when STATE_USER
          @state = STATE_PASSWORD
          return @user
        when STATE_PASSWORD
          return @password
        end
      end

      private

      STATE_USER = :USER
      STATE_PASSWORD = :PASSWORD

      def initialize(user, password)
        @user = user
        @password = password
        @state = STATE_USER
      end
    end
    add_authenticator "LOGIN", LoginAuthenticator

    class PlainAuthenticator
      def process(data)
        return "\0#{@user}\0#{@password}"
      end

      private

      def initialize(user, password)
        @user = user
        @password = password
      end
    end
    add_authenticator "PLAIN", PlainAuthenticator

    class CramMD5Authenticator
      def process(challenge)
        digest = hmac_md5(challenge, @password)
        return @user + " " + digest
      end

      private

      def initialize(user, password)
        @user = user
        @password = password
      end

      def hmac_md5(text, key)
        if key.length > 64
          key = Digest::MD5.digest(key)
        end

        k_ipad = key + "\0" * (64 - key.length)
        k_opad = key + "\0" * (64 - key.length)
        for i in 0..63
          k_ipad[i] = (k_ipad[i].ord ^ 0x36).chr
          k_opad[i] = (k_opad[i].ord ^ 0x5c).chr
        end

        digest = Digest::MD5.digest(k_ipad + text)

        return Digest::MD5.hexdigest(k_opad + digest)
      end
    end
    add_authenticator "CRAM-MD5", CramMD5Authenticator

    class DigestMD5Authenticator
      def process(challenge)
        case @stage
        when STAGE_ONE
          @stage = STAGE_TWO
          sparams = {}
          c = StringScanner.new(challenge)
          while c.scan(/(?:\s*,)?\s*(\w+)=("(?:[^\\"]+|\\.)*"|[^,]+)\s*/)
            k, v = c[1], c[2]
            if v =~ /^"(.*)"$/
              v = $1
              if v =~ /,/
                v = v.split(',')
              end
            end
            sparams[k] = v
          end

          raise DataFormatError, "Bad Challenge: '#{challenge}'" unless c.rest.size == 0
          raise Error, "Server does not support auth (qop = #{sparams['qop'].join(',')})" unless sparams['qop'].include?("auth")

          response = {
            :nonce => sparams['nonce'],
            :username => @user,
            :realm => sparams['realm'],
            :cnonce => Digest::MD5.hexdigest("%.15f:%.15f:%d" % [Time.now.to_f, rand, Process.pid.to_s]),
            :'digest-uri' => 'imap/' + sparams['realm'],
            :qop => 'auth',
            :maxbuf => 65535,
            :nc => "%08d" % nc(sparams['nonce']),
            :charset => sparams['charset'],
          }

          response[:authzid] = @authname unless @authname.nil?

          a0 = Digest::MD5.digest( [ response.values_at(:username, :realm), @password ].join(':') )

          a1 = [ a0, response.values_at(:nonce,:cnonce) ].join(':')
          a1 << ':' + response[:authzid] unless response[:authzid].nil?

          a2 = "AUTHENTICATE:" + response[:'digest-uri']
          a2 << ":00000000000000000000000000000000" if response[:qop] and response[:qop] =~ /^auth-(?:conf|int)$/

          response[:response] = Digest::MD5.hexdigest(
            [
             Digest::MD5.hexdigest(a1),
             response.values_at(:nonce, :nc, :cnonce, :qop),
             Digest::MD5.hexdigest(a2)
            ].join(':')
          )

          return response.keys.map {|key| qdval(key.to_s, response[key]) }.join(',')
        when STAGE_TWO
          @stage = nil
          if challenge =~ /rspauth=/
            return ''
          else
            raise ResponseParseError, challenge
          end
        else
          raise ResponseParseError, challenge
        end
      end

      def initialize(user, password, authname = nil)
        @user, @password, @authname = user, password, authname
        @nc, @stage = {}, STAGE_ONE
      end

      private

      STAGE_ONE = :stage_one
      STAGE_TWO = :stage_two

      def nc(nonce)
        if @nc.has_key? nonce
          @nc[nonce] = @nc[nonce] + 1
        else
          @nc[nonce] = 1
        end
        return @nc[nonce]
      end

      def qdval(k, v)
        return if k.nil? or v.nil?
        if %w"username authzid realm nonce cnonce digest-uri qop".include? k
          v.gsub!(/([\\"])/, "\\\1")
          return '%s="%s"' % [k, v]
        else
          return '%s=%s' % [k, v]
        end
      end
    end
    add_authenticator "DIGEST-MD5", DigestMD5Authenticator

    class Error < StandardError
    end

    class DataFormatError < Error
    end

    class ResponseParseError < Error
    end

    class ResponseError < Error

      attr_accessor :response

      def initialize(response)
        @response = response

        super @response.data.text
      end

    end

    class NoResponseError < ResponseError
    end

    class BadResponseError < ResponseError
    end

    class ByeResponseError < ResponseError
    end

    class FlagCountError < Error
    end
  end
end
