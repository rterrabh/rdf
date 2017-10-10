class CGI

  $CGI_ENV = ENV    # for FCGI support

  CR  = "\015"

  LF  = "\012"

  EOL = CR + LF

  REVISION = '$Id$' #:nodoc:

  NEEDS_BINMODE = File::BINARY != 0

  PATH_SEPARATOR = {'UNIX'=>'/', 'WINDOWS'=>'\\', 'MACINTOSH'=>':'}

  HTTP_STATUS = {
    "OK"                  => "200 OK",
    "PARTIAL_CONTENT"     => "206 Partial Content",
    "MULTIPLE_CHOICES"    => "300 Multiple Choices",
    "MOVED"               => "301 Moved Permanently",
    "REDIRECT"            => "302 Found",
    "NOT_MODIFIED"        => "304 Not Modified",
    "BAD_REQUEST"         => "400 Bad Request",
    "AUTH_REQUIRED"       => "401 Authorization Required",
    "FORBIDDEN"           => "403 Forbidden",
    "NOT_FOUND"           => "404 Not Found",
    "METHOD_NOT_ALLOWED"  => "405 Method Not Allowed",
    "NOT_ACCEPTABLE"      => "406 Not Acceptable",
    "LENGTH_REQUIRED"     => "411 Length Required",
    "PRECONDITION_FAILED" => "412 Precondition Failed",
    "SERVER_ERROR"        => "500 Internal Server Error",
    "NOT_IMPLEMENTED"     => "501 Method Not Implemented",
    "BAD_GATEWAY"         => "502 Bad Gateway",
    "VARIANT_ALSO_VARIES" => "506 Variant Also Negotiates"
  }


  def env_table
    ENV
  end

  def stdinput
    $stdin
  end

  def stdoutput
    $stdout
  end

  private :env_table, :stdinput, :stdoutput

  def http_header(options='text/html')
    if options.is_a?(String)
      content_type = options
      buf = _header_for_string(content_type)
    elsif options.is_a?(Hash)
      if options.size == 1 && options.has_key?('type')
        content_type = options['type']
        buf = _header_for_string(content_type)
      else
        buf = _header_for_hash(options.dup)
      end
    else
      raise ArgumentError.new("expected String or Hash but got #{options.class}")
    end
    if defined?(MOD_RUBY)
      _header_for_modruby(buf)
      return ''
    else
      buf << EOL    # empty line of separator
      return buf
    end
  end # http_header()

  alias :header :http_header

  def _header_for_string(content_type) #:nodoc:
    buf = ''
    if nph?()
      buf << "#{$CGI_ENV['SERVER_PROTOCOL'] || 'HTTP/1.0'} 200 OK#{EOL}"
      buf << "Date: #{CGI.rfc1123_date(Time.now)}#{EOL}"
      buf << "Server: #{$CGI_ENV['SERVER_SOFTWARE']}#{EOL}"
      buf << "Connection: close#{EOL}"
    end
    buf << "Content-Type: #{content_type}#{EOL}"
    if @output_cookies
      @output_cookies.each {|cookie| buf << "Set-Cookie: #{cookie}#{EOL}" }
    end
    return buf
  end # _header_for_string
  private :_header_for_string

  def _header_for_hash(options)  #:nodoc:
    buf = ''
    options['type'] ||= 'text/html'
    charset = options.delete('charset')
    options['type'] += "; charset=#{charset}" if charset
    options.delete('nph') if defined?(MOD_RUBY)
    if options.delete('nph') || nph?()
      protocol = $CGI_ENV['SERVER_PROTOCOL'] || 'HTTP/1.0'
      status = options.delete('status')
      status = HTTP_STATUS[status] || status || '200 OK'
      buf << "#{protocol} #{status}#{EOL}"
      buf << "Date: #{CGI.rfc1123_date(Time.now)}#{EOL}"
      options['server'] ||= $CGI_ENV['SERVER_SOFTWARE'] || ''
      options['connection'] ||= 'close'
    end
    status = options.delete('status')
    buf << "Status: #{HTTP_STATUS[status] || status}#{EOL}" if status
    server = options.delete('server')
    buf << "Server: #{server}#{EOL}" if server
    connection = options.delete('connection')
    buf << "Connection: #{connection}#{EOL}" if connection
    type = options.delete('type')
    buf << "Content-Type: #{type}#{EOL}" #if type
    length = options.delete('length')
    buf << "Content-Length: #{length}#{EOL}" if length
    language = options.delete('language')
    buf << "Content-Language: #{language}#{EOL}" if language
    expires = options.delete('expires')
    buf << "Expires: #{CGI.rfc1123_date(expires)}#{EOL}" if expires
    if cookie = options.delete('cookie')
      case cookie
      when String, Cookie
        buf << "Set-Cookie: #{cookie}#{EOL}"
      when Array
        arr = cookie
        arr.each {|c| buf << "Set-Cookie: #{c}#{EOL}" }
      when Hash
        hash = cookie
        hash.each_value {|c| buf << "Set-Cookie: #{c}#{EOL}" }
      end
    end
    if @output_cookies
      @output_cookies.each {|c| buf << "Set-Cookie: #{c}#{EOL}" }
    end
    options.each do |key, value|
      buf << "#{key}: #{value}#{EOL}"
    end
    return buf
  end # _header_for_hash
  private :_header_for_hash

  def nph?  #:nodoc:
    return /IIS\/(\d+)/.match($CGI_ENV['SERVER_SOFTWARE']) && $1.to_i < 5
  end

  def _header_for_modruby(buf)  #:nodoc:
    request = Apache::request
    buf.scan(/([^:]+): (.+)#{EOL}/o) do |name, value|
      warn sprintf("name:%s value:%s\n", name, value) if $DEBUG
      case name
      when 'Set-Cookie'
        request.headers_out.add(name, value)
      when /^status$/i
        request.status_line = value
        request.status = value.to_i
      when /^content-type$/i
        request.content_type = value
      when /^content-encoding$/i
        request.content_encoding = value
      when /^location$/i
        request.status = 302 if request.status == 200
        request.headers_out[name] = value
      else
        request.headers_out[name] = value
      end
    end
    request.send_http_header
    return ''
  end
  private :_header_for_modruby

  def out(options = "text/html") # :yield:

    options = { "type" => options } if options.kind_of?(String)
    content = yield
    options["length"] = content.bytesize.to_s
    output = stdoutput
    output.binmode if defined? output.binmode
    output.print http_header(options)
    output.print content unless "HEAD" == env_table['REQUEST_METHOD']
  end


  def print(*options)
    stdoutput.print(*options)
  end

  def CGI::parse(query)
    params = {}
    query.split(/[&;]/).each do |pairs|
      key, value = pairs.split('=',2).collect{|v| CGI::unescape(v) }

      next unless key

      params[key] ||= []
      params[key].push(value) if value
    end

    params.default=[].freeze
    params
  end


  MAX_MULTIPART_COUNT = 128

  module QueryExtension

    %w[ CONTENT_LENGTH SERVER_PORT ].each do |env|
      #nodyna <define_method-1950> <DM MODERATE (array)>
      define_method(env.sub(/^HTTP_/, '').downcase) do
        (val = env_table[env]) && Integer(val)
      end
    end

    %w[ AUTH_TYPE CONTENT_TYPE GATEWAY_INTERFACE PATH_INFO
        PATH_TRANSLATED QUERY_STRING REMOTE_ADDR REMOTE_HOST
        REMOTE_IDENT REMOTE_USER REQUEST_METHOD SCRIPT_NAME
        SERVER_NAME SERVER_PROTOCOL SERVER_SOFTWARE

        HTTP_ACCEPT HTTP_ACCEPT_CHARSET HTTP_ACCEPT_ENCODING
        HTTP_ACCEPT_LANGUAGE HTTP_CACHE_CONTROL HTTP_FROM HTTP_HOST
        HTTP_NEGOTIATE HTTP_PRAGMA HTTP_REFERER HTTP_USER_AGENT ].each do |env|
      #nodyna <define_method-1951> <DM MODERATE (array)>
      define_method(env.sub(/^HTTP_/, '').downcase) do
        env_table[env]
      end
    end

    def raw_cookie
      env_table["HTTP_COOKIE"]
    end

    def raw_cookie2
      env_table["HTTP_COOKIE2"]
    end

    attr_accessor :cookies

    attr_reader :params

    attr_reader :files

    def params=(hash)
      @params.clear
      @params.update(hash)
    end

    def read_multipart(boundary, content_length)
      stdin = stdinput
      first_line = "--#{boundary}#{EOL}"
      content_length -= first_line.bytesize
      status = stdin.read(first_line.bytesize)
      raise EOFError.new("no content body")  unless status
      raise EOFError.new("bad content body") unless first_line == status
      params = {}
      @files = {}
      boundary_rexp = /--#{Regexp.quote(boundary)}(#{EOL}|--)/
      boundary_size = "#{EOL}--#{boundary}#{EOL}".bytesize
      buf = ''
      bufsize = 10 * 1024
      max_count = MAX_MULTIPART_COUNT
      n = 0
      tempfiles = []
      while true
        (n += 1) < max_count or raise StandardError.new("too many parameters.")
        body = create_body(bufsize < content_length)
        tempfiles << body if defined?(Tempfile) && body.kind_of?(Tempfile)
        class << body
          if method_defined?(:path)
            alias local_path path
          else
            def local_path
              nil
            end
          end
          attr_reader :original_filename, :content_type
        end
        head = nil
        separator = EOL * 2
        until head && matched = boundary_rexp.match(buf)
          if !head && pos = buf.index(separator)
            len  = pos + EOL.bytesize
            head = buf[0, len]
            buf  = buf[(pos+separator.bytesize)..-1]
          else
            if head && buf.size > boundary_size
              len = buf.size - boundary_size
              body.print(buf[0, len])
              buf[0, len] = ''
            end
            c = stdin.read(bufsize < content_length ? bufsize : content_length)
            raise EOFError.new("bad content body") if c.nil? || c.empty?
            buf << c
            content_length -= c.bytesize
          end
        end
        m = matched
        len = m.begin(0)
        s = buf[0, len]
        if s =~ /(\r?\n)\z/
          s = buf[0, len - $1.bytesize]
        end
        body.print(s)
        buf = buf[m.end(0)..-1]
        boundary_end = m[1]
        content_length = -1 if boundary_end == '--'
        body.rewind
        /Content-Disposition:.* filename=(?:"(.*?)"|([^;\r\n]*))/i.match(head)
        filename = $1 || $2 || ''
        filename = CGI.unescape(filename) if unescape_filename?()
        #nodyna <instance_variable_set-1952> <not yet classified>
        body.instance_variable_set(:@original_filename, filename.taint)
        /Content-Type: (.*)/i.match(head)
        (content_type = $1 || '').chomp!
        #nodyna <instance_variable_set-1953> <not yet classified>
        body.instance_variable_set(:@content_type, content_type.taint)
        /Content-Disposition:.* name=(?:"(.*?)"|([^;\r\n]*))/i.match(head)
        name = $1 || $2 || ''
        if body.original_filename.empty?
          value=body.read.dup.force_encoding(@accept_charset)
          body.close! if defined?(Tempfile) && body.kind_of?(Tempfile)
          (params[name] ||= []) << value
          unless value.valid_encoding?
            if @accept_charset_error_block
              @accept_charset_error_block.call(name,value)
            else
              raise InvalidEncoding,"Accept-Charset encoding error"
            end
          end
          #nodyna <class_eval-1954> <not yet classified>
          class << params[name].last;self;end.class_eval do
            #nodyna <define_method-1955> <DM MODERATE (events)>
            define_method(:read){self}
            #nodyna <define_method-1956> <DM MODERATE (events)>
            define_method(:original_filename){""}
            #nodyna <define_method-1957> <DM MODERATE (events)>
            define_method(:content_type){""}
          end
        else
          (params[name] ||= []) << body
          @files[name]=body
        end
        break if content_length == -1
      end
      raise EOFError, "bad boundary end of body part" unless boundary_end =~ /--/
      params.default = []
      params
    rescue Exception
      if tempfiles
        tempfiles.each {|t|
          if t.path
            t.close!
          end
        }
      end
      raise
    end # read_multipart
    private :read_multipart
    def create_body(is_large)  #:nodoc:
      if is_large
        require 'tempfile'
        body = Tempfile.new('CGI', encoding: Encoding::ASCII_8BIT)
      else
        begin
          require 'stringio'
          body = StringIO.new("".force_encoding(Encoding::ASCII_8BIT))
        rescue LoadError
          require 'tempfile'
          body = Tempfile.new('CGI', encoding: Encoding::ASCII_8BIT)
        end
      end
      body.binmode if defined? body.binmode
      return body
    end
    def unescape_filename?  #:nodoc:
      user_agent = $CGI_ENV['HTTP_USER_AGENT']
      return /Mac/i.match(user_agent) && /Mozilla/i.match(user_agent) && !/MSIE/i.match(user_agent)
    end

    def read_from_cmdline
      require "shellwords"

      string = unless ARGV.empty?
        ARGV.join(' ')
      else
        if STDIN.tty?
          STDERR.print(
            %|(offline mode: enter name=value pairs on standard input)\n|
          )
        end
        array = readlines rescue nil
        if not array.nil?
            array.join(' ').gsub(/\n/n, '')
        else
            ""
        end
      end.gsub(/\\=/n, '%3D').gsub(/\\&/n, '%26')

      words = Shellwords.shellwords(string)

      if words.find{|x| /=/n.match(x) }
        words.join('&')
      else
        words.join('+')
      end
    end
    private :read_from_cmdline

    def initialize_query()
      if ("POST" == env_table['REQUEST_METHOD']) and
        %r|\Amultipart/form-data.*boundary=\"?([^\";,]+)\"?|.match(env_table['CONTENT_TYPE'])
        current_max_multipart_length = @max_multipart_length.respond_to?(:call) ? @max_multipart_length.call : @max_multipart_length
        raise StandardError.new("too large multipart data.") if env_table['CONTENT_LENGTH'].to_i > current_max_multipart_length
        boundary = $1.dup
        @multipart = true
        @params = read_multipart(boundary, Integer(env_table['CONTENT_LENGTH']))
      else
        @multipart = false
        @params = CGI::parse(
                    case env_table['REQUEST_METHOD']
                    when "GET", "HEAD"
                      if defined?(MOD_RUBY)
                        Apache::request.args or ""
                      else
                        env_table['QUERY_STRING'] or ""
                      end
                    when "POST"
                      stdinput.binmode if defined? stdinput.binmode
                      stdinput.read(Integer(env_table['CONTENT_LENGTH'])) or ''
                    else
                      read_from_cmdline
                    end.dup.force_encoding(@accept_charset)
                  )
        unless Encoding.find(@accept_charset) == Encoding::ASCII_8BIT
          @params.each do |key,values|
            values.each do |value|
              unless value.valid_encoding?
                if @accept_charset_error_block
                  @accept_charset_error_block.call(key,value)
                else
                  raise InvalidEncoding,"Accept-Charset encoding error"
                end
              end
            end
          end
        end
      end

      @cookies = CGI::Cookie::parse((env_table['HTTP_COOKIE'] or env_table['COOKIE']))
    end
    private :initialize_query

    def multipart?
      @multipart
    end

    def [](key)
      params = @params[key]
      return '' unless params
      value = params[0]
      if @multipart
        if value
          return value
        elsif defined? StringIO
          StringIO.new("".force_encoding(Encoding::ASCII_8BIT))
        else
          Tempfile.new("CGI",encoding: Encoding::ASCII_8BIT)
        end
      else
        str = if value then value.dup else "" end
        str
      end
    end

    def keys(*args)
      @params.keys(*args)
    end

    def has_key?(*args)
      @params.has_key?(*args)
    end
    alias key? has_key?
    alias include? has_key?

  end # QueryExtension

  class InvalidEncoding < Exception; end

  @@accept_charset="UTF-8"

  def self.accept_charset
    @@accept_charset
  end

  def self.accept_charset=(accept_charset)
    @@accept_charset=accept_charset
  end

  attr_reader :accept_charset

  @@max_multipart_length= 128 * 1024 * 1024

  def initialize(options = {}, &block) # :yields: name, value
    @accept_charset_error_block = block_given? ? block : nil
    @options={
      :accept_charset=>@@accept_charset,
      :max_multipart_length=>@@max_multipart_length
    }
    case options
    when Hash
      @options.merge!(options)
    when String
      @options[:tag_maker]=options
    end
    @accept_charset=@options[:accept_charset]
    @max_multipart_length=@options[:max_multipart_length]
    if defined?(MOD_RUBY) && !ENV.key?("GATEWAY_INTERFACE")
      Apache.request.setup_cgi_env
    end

    extend QueryExtension
    @multipart = false

    initialize_query()  # set @params, @cookies
    @output_cookies = nil
    @output_hidden = nil

    case @options[:tag_maker]
    when "html3"
      require 'cgi/html'
      extend Html3
      extend HtmlExtension
    when "html4"
      require 'cgi/html'
      extend Html4
      extend HtmlExtension
    when "html4Tr"
      require 'cgi/html'
      extend Html4Tr
      extend HtmlExtension
    when "html4Fr"
      require 'cgi/html'
      extend Html4Tr
      extend Html4Fr
      extend HtmlExtension
    when "html5"
      require 'cgi/html'
      extend Html5
      extend HtmlExtension
    end
  end

end   # class CGI
