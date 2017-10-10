require 'cgi/util'
class CGI
  class Cookie < Array
    @@accept_charset="UTF-8" unless defined?(@@accept_charset)

    def initialize(name = "", *value)
      @domain = nil
      @expires = nil
      if name.kind_of?(String)
        @name = name
        %r|^(.*/)|.match(ENV["SCRIPT_NAME"])
        @path = ($1 or "")
        @secure = false
        return super(value)
      end

      options = name
      unless options.has_key?("name")
        raise ArgumentError, "`name' required"
      end

      @name = options["name"]
      value = Array(options["value"])
      if options["path"]
        @path = options["path"]
      else
        %r|^(.*/)|.match(ENV["SCRIPT_NAME"])
        @path = ($1 or "")
      end
      @domain = options["domain"]
      @expires = options["expires"]
      @secure = options["secure"] == true ? true : false

      super(value)
    end

    attr_accessor :name
    attr_accessor :path
    attr_accessor :domain
    attr_accessor :expires
    attr_reader("secure")

    def value
      self
    end

    def value=(val)
      replace(Array(val))
    end

    def secure=(val)
      @secure = val if val == true or val == false
      @secure
    end

    def to_s
      val = collect{|v| CGI.escape(v) }.join("&")
      buf = "#{@name}=#{val}"
      buf << "; domain=#{@domain}" if @domain
      buf << "; path=#{@path}"     if @path
      buf << "; expires=#{CGI::rfc1123_date(@expires)}" if @expires
      buf << "; secure"            if @secure == true
      buf
    end

    def self.parse(raw_cookie)
      cookies = Hash.new([])
      return cookies unless raw_cookie

      raw_cookie.split(/[;,]\s?/).each do |pairs|
        name, values = pairs.split('=',2)
        next unless name and values
        name = CGI.unescape(name)
        values ||= ""
        values = values.split('&').collect{|v| CGI.unescape(v,@@accept_charset) }
        if cookies.has_key?(name)
          values = cookies[name].value + values
        end
        cookies[name] = Cookie.new(name, *values)
      end

      cookies
    end

    def inspect
      "#<CGI::Cookie: #{self.to_s.inspect}>"
    end

  end # class Cookie
end


