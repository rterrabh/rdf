class Net::HTTPResponse
  class << self
    def body_permitted?
      self::HAS_BODY
    end

    def exception_type   # :nodoc: internal use only
      self::EXCEPTION_TYPE
    end

    def read_new(sock)   #:nodoc: internal use only
      httpv, code, msg = read_status_line(sock)
      res = response_class(code).new(httpv, code, msg)
      each_response_header(sock) do |k,v|
        res.add_field k, v
      end
      res
    end

    private

    def read_status_line(sock)
      str = sock.readline
      m = /\AHTTP(?:\/(\d+\.\d+))?\s+(\d\d\d)(?:\s+(.*))?\z/in.match(str) or
        raise Net::HTTPBadResponse, "wrong status line: #{str.dump}"
      m.captures
    end

    def response_class(code)
      CODE_TO_OBJ[code] or
      CODE_CLASS_TO_OBJ[code[0,1]] or
      Net::HTTPUnknownResponse
    end

    def each_response_header(sock)
      key = value = nil
      while true
        line = sock.readuntil("\n", true).sub(/\s+\z/, '')
        break if line.empty?
        if line[0] == ?\s or line[0] == ?\t and value
          value << ' ' unless value.empty?
          value << line.strip
        else
          yield key, value if key
          key, value = line.strip.split(/\s*:\s*/, 2)
          raise Net::HTTPBadResponse, 'wrong header line format' if value.nil?
        end
      end
      yield key, value if key
    end
  end

  public

  include Net::HTTPHeader

  def initialize(httpv, code, msg)   #:nodoc: internal use only
    @http_version = httpv
    @code         = code
    @message      = msg
    initialize_http_header nil
    @body = nil
    @read = false
    @uri  = nil
    @decode_content = false
  end

  attr_reader :http_version

  attr_reader :code

  attr_reader :message
  alias msg message   # :nodoc: obsolete

  attr_reader :uri

  attr_accessor :decode_content

  def inspect
    "#<#{self.class} #{@code} #{@message} readbody=#{@read}>"
  end


  def code_type   #:nodoc:
    self.class
  end

  def error!   #:nodoc:
    raise error_type().new(@code + ' ' + @message.dump, self)
  end

  def error_type   #:nodoc:
    self.class::EXCEPTION_TYPE
  end

  def value
    error! unless self.kind_of?(Net::HTTPSuccess)
  end

  def uri= uri # :nodoc:
    @uri = uri.dup if uri
  end


  def response   #:nodoc:
    warn "#{caller(1)[0]}: warning: Net::HTTPResponse#response is obsolete" if $VERBOSE
    self
  end

  def header   #:nodoc:
    warn "#{caller(1)[0]}: warning: Net::HTTPResponse#header is obsolete" if $VERBOSE
    self
  end

  def read_header   #:nodoc:
    warn "#{caller(1)[0]}: warning: Net::HTTPResponse#read_header is obsolete" if $VERBOSE
    self
  end


  def reading_body(sock, reqmethodallowbody)  #:nodoc: internal use only
    @socket = sock
    @body_exist = reqmethodallowbody && self.class.body_permitted?
    begin
      yield
      self.body   # ensure to read body
    ensure
      @socket = nil
    end
  end

  def read_body(dest = nil, &block)
    if @read
      raise IOError, "#{self.class}\#read_body called twice" if dest or block
      return @body
    end
    to = procdest(dest, block)
    stream_check
    if @body_exist
      read_body_0 to
      @body = to
    else
      @body = nil
    end
    @read = true

    @body
  end

  def body
    read_body()
  end

  def body=(value)
    @body = value
  end

  alias entity body   #:nodoc: obsolete

  private


  def inflater # :nodoc:
    return yield @socket unless Net::HTTP::HAVE_ZLIB
    return yield @socket unless @decode_content
    return yield @socket if self['content-range']

    v = self['content-encoding']
    case v && v.downcase
    when 'deflate', 'gzip', 'x-gzip' then
      self.delete 'content-encoding'

      inflate_body_io = Inflater.new(@socket)

      begin
        yield inflate_body_io
      ensure
        orig_err = $!
        begin
          inflate_body_io.finish
        rescue => err
          raise orig_err || err
        end
      end
    when 'none', 'identity' then
      self.delete 'content-encoding'

      yield @socket
    else
      yield @socket
    end
  end

  def read_body_0(dest)
    inflater do |inflate_body_io|
      if chunked?
        read_chunked dest, inflate_body_io
        return
      end

      @socket = inflate_body_io

      clen = content_length()
      if clen
        @socket.read clen, dest, true   # ignore EOF
        return
      end
      clen = range_length()
      if clen
        @socket.read clen, dest
        return
      end
      @socket.read_all dest
    end
  end


  def read_chunked(dest, chunk_data_io) # :nodoc:
    total = 0
    while true
      line = @socket.readline
      hexlen = line.slice(/[0-9a-fA-F]+/) or
          raise Net::HTTPBadResponse, "wrong chunk size line: #{line}"
      len = hexlen.hex
      break if len == 0
      begin
        chunk_data_io.read len, dest
      ensure
        total += len
        @socket.read 2   # \r\n
      end
    end
    until @socket.readline.empty?
    end
  end

  def stream_check
    raise IOError, 'attempt to read body out of block' if @socket.closed?
  end

  def procdest(dest, block)
    raise ArgumentError, 'both arg and block given for HTTP method' if
      dest and block
    if block
      Net::ReadAdapter.new(block)
    else
      dest || ''
    end
  end


  class Inflater # :nodoc:


    def initialize socket
      @socket = socket
      @inflate = Zlib::Inflate.new(32 + Zlib::MAX_WBITS)
    end


    def finish
      return if @inflate.total_in == 0
      @inflate.finish
    end


    def inflate_adapter(dest)
      if dest.respond_to?(:set_encoding)
        dest.set_encoding(Encoding::ASCII_8BIT)
      elsif dest.respond_to?(:force_encoding)
        dest.force_encoding(Encoding::ASCII_8BIT)
      end
      block = proc do |compressed_chunk|
        @inflate.inflate(compressed_chunk) do |chunk|
          dest << chunk
        end
      end

      Net::ReadAdapter.new(block)
    end


    def read clen, dest, ignore_eof = false
      temp_dest = inflate_adapter(dest)

      @socket.read clen, temp_dest, ignore_eof
    end


    def read_all dest
      temp_dest = inflate_adapter(dest)

      @socket.read_all temp_dest
    end

  end

end

