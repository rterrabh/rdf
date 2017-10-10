module Net::HTTPHeader

  def initialize_http_header(initheader)
    @header = {}
    return unless initheader
    initheader.each do |key, value|
      warn "net/http: warning: duplicated HTTP header: #{key}" if key?(key) and $VERBOSE
      @header[key.downcase] = [value.strip]
    end
  end

  def size   #:nodoc: obsolete
    @header.size
  end

  alias length size   #:nodoc: obsolete

  def [](key)
    a = @header[key.downcase] or return nil
    a.join(', ')
  end

  def []=(key, val)
    unless val
      @header.delete key.downcase
      return val
    end
    @header[key.downcase] = [val]
  end

  def add_field(key, val)
    if @header.key?(key.downcase)
      @header[key.downcase].push val
    else
      @header[key.downcase] = [val]
    end
  end

  def get_fields(key)
    return nil unless @header[key.downcase]
    @header[key.downcase].dup
  end

  def fetch(key, *args, &block)   #:yield: +key+
    a = @header.fetch(key.downcase, *args, &block)
    a.kind_of?(Array) ? a.join(', ') : a
  end

  def each_header   #:yield: +key+, +value+
    block_given? or return enum_for(__method__)
    @header.each do |k,va|
      yield k, va.join(', ')
    end
  end

  alias each each_header

  def each_name(&block)   #:yield: +key+
    block_given? or return enum_for(__method__)
    @header.each_key(&block)
  end

  alias each_key each_name

  def each_capitalized_name  #:yield: +key+
    block_given? or return enum_for(__method__)
    @header.each_key do |k|
      yield capitalize(k)
    end
  end

  def each_value   #:yield: +value+
    block_given? or return enum_for(__method__)
    @header.each_value do |va|
      yield va.join(', ')
    end
  end

  def delete(key)
    @header.delete(key.downcase)
  end

  def key?(key)
    @header.key?(key.downcase)
  end

  def to_hash
    @header.dup
  end

  def each_capitalized
    block_given? or return enum_for(__method__)
    @header.each do |k,v|
      yield capitalize(k), v.join(', ')
    end
  end

  alias canonical_each each_capitalized

  def capitalize(name)
    name.split(/-/).map {|s| s.capitalize }.join('-')
  end
  private :capitalize

  def range
    return nil unless @header['range']

    value = self['Range']
    unless /\Abytes=((?:,[ \t]*)*(?:\d+-\d*|-\d+)(?:[ \t]*,(?:[ \t]*\d+-\d*|-\d+)?)*)\z/ =~ value
      raise Net::HTTPHeaderSyntaxError, "invalid syntax for byte-ranges-specifier: '#{value}'"
    end

    byte_range_set = $1
    result = byte_range_set.split(/,/).map {|spec|
      m = /(\d+)?\s*-\s*(\d+)?/i.match(spec) or
              raise Net::HTTPHeaderSyntaxError, "invalid byte-range-spec: '#{spec}'"
      d1 = m[1].to_i
      d2 = m[2].to_i
      if m[1] and m[2]
        if d1 > d2
          raise Net::HTTPHeaderSyntaxError, "last-byte-pos MUST greater than or equal to first-byte-pos but '#{spec}'"
        end
        d1..d2
      elsif m[1]
        d1..-1
      elsif m[2]
        -d2..-1
      else
        raise Net::HTTPHeaderSyntaxError, 'range is not specified'
      end
    }
    if result.size == 1 && result[0].begin == 0 && result[0].end == -1
      raise Net::HTTPHeaderSyntaxError, 'only one suffix-byte-range-spec with zero suffix-length'
    end
    result
  end

  def set_range(r, e = nil)
    unless r
      @header.delete 'range'
      return r
    end
    r = (r...r+e) if e
    case r
    when Numeric
      n = r.to_i
      rangestr = (n > 0 ? "0-#{n-1}" : "-#{-n}")
    when Range
      first = r.first
      last = r.end
      last -= 1 if r.exclude_end?
      if last == -1
        rangestr = (first > 0 ? "#{first}-" : "-#{-first}")
      else
        raise Net::HTTPHeaderSyntaxError, 'range.first is negative' if first < 0
        raise Net::HTTPHeaderSyntaxError, 'range.last is negative' if last < 0
        raise Net::HTTPHeaderSyntaxError, 'must be .first < .last' if first > last
        rangestr = "#{first}-#{last}"
      end
    else
      raise TypeError, 'Range/Integer is required'
    end
    @header['range'] = ["bytes=#{rangestr}"]
    r
  end

  alias range= set_range

  def content_length
    return nil unless key?('Content-Length')
    len = self['Content-Length'].slice(/\d+/) or
        raise Net::HTTPHeaderSyntaxError, 'wrong Content-Length format'
    len.to_i
  end

  def content_length=(len)
    unless len
      @header.delete 'content-length'
      return nil
    end
    @header['content-length'] = [len.to_i.to_s]
  end

  def chunked?
    return false unless @header['transfer-encoding']
    field = self['Transfer-Encoding']
    (/(?:\A|[^\-\w])chunked(?![\-\w])/i =~ field) ? true : false
  end

  def content_range
    return nil unless @header['content-range']
    m = %r<bytes\s+(\d+)-(\d+)/(\d+|\*)>i.match(self['Content-Range']) or
        raise Net::HTTPHeaderSyntaxError, 'wrong Content-Range format'
    m[1].to_i .. m[2].to_i
  end

  def range_length
    r = content_range() or return nil
    r.end - r.begin + 1
  end

  def content_type
    return nil unless main_type()
    if sub_type()
    then "#{main_type()}/#{sub_type()}"
    else main_type()
    end
  end

  def main_type
    return nil unless @header['content-type']
    self['Content-Type'].split(';').first.to_s.split('/')[0].to_s.strip
  end

  def sub_type
    return nil unless @header['content-type']
    _, sub = *self['Content-Type'].split(';').first.to_s.split('/')
    return nil unless sub
    sub.strip
  end

  def type_params
    result = {}
    list = self['Content-Type'].to_s.split(';')
    list.shift
    list.each do |param|
      k, v = *param.split('=', 2)
      result[k.strip] = v.strip
    end
    result
  end

  def set_content_type(type, params = {})
    @header['content-type'] = [type + params.map{|k,v|"; #{k}=#{v}"}.join('')]
  end

  alias content_type= set_content_type

  def set_form_data(params, sep = '&')
    query = URI.encode_www_form(params)
    query.gsub!(/&/, sep) if sep != '&'
    self.body = query
    self.content_type = 'application/x-www-form-urlencoded'
  end

  alias form_data= set_form_data

  def set_form(params, enctype='application/x-www-form-urlencoded', formopt={})
    @body_data = params
    @body = nil
    @body_stream = nil
    @form_option = formopt
    case enctype
    when /\Aapplication\/x-www-form-urlencoded\z/i,
      /\Amultipart\/form-data\z/i
      self.content_type = enctype
    else
      raise ArgumentError, "invalid enctype: #{enctype}"
    end
  end

  def basic_auth(account, password)
    @header['authorization'] = [basic_encode(account, password)]
  end

  def proxy_basic_auth(account, password)
    @header['proxy-authorization'] = [basic_encode(account, password)]
  end

  def basic_encode(account, password)
    'Basic ' + ["#{account}:#{password}"].pack('m').delete("\r\n")
  end
  private :basic_encode

  def connection_close?
    tokens(@header['connection']).include?('close') or
    tokens(@header['proxy-connection']).include?('close')
  end

  def connection_keep_alive?
    tokens(@header['connection']).include?('keep-alive') or
    tokens(@header['proxy-connection']).include?('keep-alive')
  end

  def tokens(vals)
    return [] unless vals
    vals.map {|v| v.split(',') }.flatten\
        .reject {|str| str.strip.empty? }\
        .map {|tok| tok.strip.downcase }
  end
  private :tokens

end

