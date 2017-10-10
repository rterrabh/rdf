

module OpenSSL::Buffering
  include Enumerable


  attr_accessor :sync


  BLOCK_SIZE = 1024*16


  def initialize(*)
    super
    @eof = false
    @rbuffer = ""
    @sync = @io.sync
  end

  private


  def fill_rbuff
    begin
      @rbuffer << self.sysread(BLOCK_SIZE)
    rescue Errno::EAGAIN
      retry
    rescue EOFError
      @eof = true
    end
  end


  def consume_rbuff(size=nil)
    if @rbuffer.empty?
      nil
    else
      size = @rbuffer.size unless size
      ret = @rbuffer[0, size]
      @rbuffer[0, size] = ""
      ret
    end
  end

  public


  def read(size=nil, buf=nil)
    if size == 0
      if buf
        buf.clear
        return buf
      else
        return ""
      end
    end
    until @eof
      break if size && size <= @rbuffer.size
      fill_rbuff
    end
    ret = consume_rbuff(size) || ""
    if buf
      buf.replace(ret)
      ret = buf
    end
    (size && ret.empty?) ? nil : ret
  end


  def readpartial(maxlen, buf=nil)
    if maxlen == 0
      if buf
        buf.clear
        return buf
      else
        return ""
      end
    end
    if @rbuffer.empty?
      begin
        return sysread(maxlen, buf)
      rescue Errno::EAGAIN
        retry
      end
    end
    ret = consume_rbuff(maxlen)
    if buf
      buf.replace(ret)
      ret = buf
    end
    raise EOFError if ret.empty?
    ret
  end


  def read_nonblock(maxlen, buf=nil, exception: true)
    if maxlen == 0
      if buf
        buf.clear
        return buf
      else
        return ""
      end
    end
    if @rbuffer.empty?
      return sysread_nonblock(maxlen, buf, exception: exception)
    end
    ret = consume_rbuff(maxlen)
    if buf
      buf.replace(ret)
      ret = buf
    end
    raise EOFError if ret.empty?
    ret
  end


  def gets(eol=$/, limit=nil)
    idx = @rbuffer.index(eol)
    until @eof
      break if idx
      fill_rbuff
      idx = @rbuffer.index(eol)
    end
    if eol.is_a?(Regexp)
      size = idx ? idx+$&.size : nil
    else
      size = idx ? idx+eol.size : nil
    end
    if limit and limit >= 0
      size = [size, limit].min
    end
    consume_rbuff(size)
  end


  def each(eol=$/)
    while line = self.gets(eol)
      yield line
    end
  end
  alias each_line each


  def readlines(eol=$/)
    ary = []
    while line = self.gets(eol)
      ary << line
    end
    ary
  end


  def readline(eol=$/)
    raise EOFError if eof?
    gets(eol)
  end


  def getc
    read(1)
  end


  def each_byte # :yields: byte
    while c = getc
      yield(c.ord)
    end
  end


  def readchar
    raise EOFError if eof?
    getc
  end


  def ungetc(c)
    @rbuffer[0,0] = c.chr
  end


  def eof?
    fill_rbuff if !@eof && @rbuffer.empty?
    @eof && @rbuffer.empty?
  end
  alias eof eof?

  private


  def do_write(s)
    @wbuffer = "" unless defined? @wbuffer
    @wbuffer << s
    @wbuffer.force_encoding(Encoding::BINARY)
    @sync ||= false
    if @sync or @wbuffer.size > BLOCK_SIZE or idx = @wbuffer.rindex($/)
      remain = idx ? idx + $/.size : @wbuffer.length
      nwritten = 0
      while remain > 0
        str = @wbuffer[nwritten,remain]
        begin
          nwrote = syswrite(str)
        rescue Errno::EAGAIN
          retry
        end
        remain -= nwrote
        nwritten += nwrote
      end
      @wbuffer[0,nwritten] = ""
    end
  end

  public


  def write(s)
    do_write(s)
    s.bytesize
  end


  def write_nonblock(s, exception: true)
    flush
    syswrite_nonblock(s, exception: exception)
  end


  def << (s)
    do_write(s)
    self
  end


  def puts(*args)
    s = ""
    if args.empty?
      s << "\n"
    end
    args.each{|arg|
      s << arg.to_s
      if $/ && /\n\z/ !~ s
        s << "\n"
      end
    }
    do_write(s)
    nil
  end


  def print(*args)
    s = ""
    args.each{ |arg| s << arg.to_s }
    do_write(s)
    nil
  end


  def printf(s, *args)
    do_write(s % args)
    nil
  end


  def flush
    osync = @sync
    @sync = true
    do_write ""
    return self
  ensure
    @sync = osync
  end


  def close
    flush rescue nil
    sysclose
  end
end
