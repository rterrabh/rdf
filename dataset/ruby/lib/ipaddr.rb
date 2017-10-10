require 'socket'


class IPAddr

  IN4MASK = 0xffffffff
  IN6MASK = 0xffffffffffffffffffffffffffffffff
  IN6FORMAT = (["%.4x"] * 8).join(':')

  RE_IPV4ADDRLIKE = %r{
    \A
    (\d+) \. (\d+) \. (\d+) \. (\d+)
    \z
  }x

  RE_IPV6ADDRLIKE_FULL = %r{
    \A
    (?:
      (?: [\da-f]{1,4} : ){7} [\da-f]{1,4}
    |
      ( (?: [\da-f]{1,4} : ){6} )
      (\d+) \. (\d+) \. (\d+) \. (\d+)
    )
    \z
  }xi

  RE_IPV6ADDRLIKE_COMPRESSED = %r{
    \A
    ( (?: (?: [\da-f]{1,4} : )* [\da-f]{1,4} )? )
    ::
    ( (?:
      ( (?: [\da-f]{1,4} : )* )
      (?:
        [\da-f]{1,4}
      |
        (\d+) \. (\d+) \. (\d+) \. (\d+)
      )
    )? )
    \z
  }xi

  class Error < ArgumentError; end

  class InvalidAddressError < Error; end

  class AddressFamilyError < Error; end

  class InvalidPrefixError < InvalidAddressError; end

  attr_reader :family

  def IPAddr::new_ntoh(addr)
    return IPAddr.new(IPAddr::ntop(addr))
  end

  def IPAddr::ntop(addr)
    case addr.size
    when 4
      s = addr.unpack('C4').join('.')
    when 16
      s = IN6FORMAT % addr.unpack('n8')
    else
      raise AddressFamilyError, "unsupported address family"
    end
    return s
  end

  def &(other)
    return self.clone.set(@addr & coerce_other(other).to_i)
  end

  def |(other)
    return self.clone.set(@addr | coerce_other(other).to_i)
  end

  def >>(num)
    return self.clone.set(@addr >> num)
  end

  def <<(num)
    return self.clone.set(addr_mask(@addr << num))
  end

  def ~
    return self.clone.set(addr_mask(~@addr))
  end

  def ==(other)
    other = coerce_other(other)
    return @family == other.family && @addr == other.to_i
  end

  def mask(prefixlen)
    return self.clone.mask!(prefixlen)
  end

  def include?(other)
    other = coerce_other(other)
    if ipv4_mapped?
      if (@mask_addr >> 32) != 0xffffffffffffffffffffffff
        return false
      end
      mask_addr = (@mask_addr & IN4MASK)
      addr = (@addr & IN4MASK)
      family = Socket::AF_INET
    else
      mask_addr = @mask_addr
      addr = @addr
      family = @family
    end
    if other.ipv4_mapped?
      other_addr = (other.to_i & IN4MASK)
      other_family = Socket::AF_INET
    else
      other_addr = other.to_i
      other_family = other.family
    end

    if family != other_family
      return false
    end
    return ((addr & mask_addr) == (other_addr & mask_addr))
  end
  alias === include?

  def to_i
    return @addr
  end

  def to_s
    str = to_string
    return str if ipv4?

    str.gsub!(/\b0{1,3}([\da-f]+)\b/i, '\1')
    loop do
      break if str.sub!(/\A0:0:0:0:0:0:0:0\z/, '::')
      break if str.sub!(/\b0:0:0:0:0:0:0\b/, ':')
      break if str.sub!(/\b0:0:0:0:0:0\b/, ':')
      break if str.sub!(/\b0:0:0:0:0\b/, ':')
      break if str.sub!(/\b0:0:0:0\b/, ':')
      break if str.sub!(/\b0:0:0\b/, ':')
      break if str.sub!(/\b0:0\b/, ':')
      break
    end
    str.sub!(/:{3,}/, '::')

    if /\A::(ffff:)?([\da-f]{1,4}):([\da-f]{1,4})\z/i =~ str
      str = sprintf('::%s%d.%d.%d.%d', $1, $2.hex / 256, $2.hex % 256, $3.hex / 256, $3.hex % 256)
    end

    str
  end

  def to_string
    return _to_string(@addr)
  end

  def hton
    case @family
    when Socket::AF_INET
      return [@addr].pack('N')
    when Socket::AF_INET6
      return (0..7).map { |i|
        (@addr >> (112 - 16 * i)) & 0xffff
      }.pack('n8')
    else
      raise AddressFamilyError, "unsupported address family"
    end
  end

  def ipv4?
    return @family == Socket::AF_INET
  end

  def ipv6?
    return @family == Socket::AF_INET6
  end

  def ipv4_mapped?
    return ipv6? && (@addr >> 32) == 0xffff
  end

  def ipv4_compat?
    if !ipv6? || (@addr >> 32) != 0
      return false
    end
    a = (@addr & IN4MASK)
    return a != 0 && a != 1
  end

  def ipv4_mapped
    if !ipv4?
      raise InvalidAddressError, "not an IPv4 address"
    end
    return self.clone.set(@addr | 0xffff00000000, Socket::AF_INET6)
  end

  def ipv4_compat
    if !ipv4?
      raise InvalidAddressError, "not an IPv4 address"
    end
    return self.clone.set(@addr, Socket::AF_INET6)
  end

  def native
    if !ipv4_mapped? && !ipv4_compat?
      return self
    end
    return self.clone.set(@addr & IN4MASK, Socket::AF_INET)
  end

  def reverse
    case @family
    when Socket::AF_INET
      return _reverse + ".in-addr.arpa"
    when Socket::AF_INET6
      return ip6_arpa
    else
      raise AddressFamilyError, "unsupported address family"
    end
  end

  def ip6_arpa
    if !ipv6?
      raise InvalidAddressError, "not an IPv6 address"
    end
    return _reverse + ".ip6.arpa"
  end

  def ip6_int
    if !ipv6?
      raise InvalidAddressError, "not an IPv6 address"
    end
    return _reverse + ".ip6.int"
  end

  def succ
    return self.clone.set(@addr + 1, @family)
  end

  def <=>(other)
    other = coerce_other(other)

    return nil if other.family != @family

    return @addr <=> other.to_i
  end
  include Comparable

  def eql?(other)
    return self.class == other.class && self.hash == other.hash && self == other
  end

  def hash
    return ([@addr, @mask_addr].hash << 1) | (ipv4? ? 0 : 1)
  end

  def to_range
    begin_addr = (@addr & @mask_addr)

    case @family
    when Socket::AF_INET
      end_addr = (@addr | (IN4MASK ^ @mask_addr))
    when Socket::AF_INET6
      end_addr = (@addr | (IN6MASK ^ @mask_addr))
    else
      raise AddressFamilyError, "unsupported address family"
    end

    return clone.set(begin_addr, @family)..clone.set(end_addr, @family)
  end

  def inspect
    case @family
    when Socket::AF_INET
      af = "IPv4"
    when Socket::AF_INET6
      af = "IPv6"
    else
      raise AddressFamilyError, "unsupported address family"
    end
    return sprintf("#<%s: %s:%s/%s>", self.class.name,
                   af, _to_string(@addr), _to_string(@mask_addr))
  end

  protected

  def set(addr, *family)
    case family[0] ? family[0] : @family
    when Socket::AF_INET
      if addr < 0 || addr > IN4MASK
        raise InvalidAddressError, "invalid address"
      end
    when Socket::AF_INET6
      if addr < 0 || addr > IN6MASK
        raise InvalidAddressError, "invalid address"
      end
    else
      raise AddressFamilyError, "unsupported address family"
    end
    @addr = addr
    if family[0]
      @family = family[0]
    end
    return self
  end

  def mask!(mask)
    if mask.kind_of?(String)
      if mask =~ /^\d+$/
        prefixlen = mask.to_i
      else
        m = IPAddr.new(mask)
        if m.family != @family
          raise InvalidPrefixError, "address family is not same"
        end
        @mask_addr = m.to_i
        @addr &= @mask_addr
        return self
      end
    else
      prefixlen = mask
    end
    case @family
    when Socket::AF_INET
      if prefixlen < 0 || prefixlen > 32
        raise InvalidPrefixError, "invalid length"
      end
      masklen = 32 - prefixlen
      @mask_addr = ((IN4MASK >> masklen) << masklen)
    when Socket::AF_INET6
      if prefixlen < 0 || prefixlen > 128
        raise InvalidPrefixError, "invalid length"
      end
      masklen = 128 - prefixlen
      @mask_addr = ((IN6MASK >> masklen) << masklen)
    else
      raise AddressFamilyError, "unsupported address family"
    end
    @addr = ((@addr >> masklen) << masklen)
    return self
  end

  private

  def initialize(addr = '::', family = Socket::AF_UNSPEC)
    if !addr.kind_of?(String)
      case family
      when Socket::AF_INET, Socket::AF_INET6
        set(addr.to_i, family)
        @mask_addr = (family == Socket::AF_INET) ? IN4MASK : IN6MASK
        return
      when Socket::AF_UNSPEC
        raise AddressFamilyError, "address family must be specified"
      else
        raise AddressFamilyError, "unsupported address family: #{family}"
      end
    end
    prefix, prefixlen = addr.split('/')
    if prefix =~ /^\[(.*)\]$/i
      prefix = $1
      family = Socket::AF_INET6
    end
    @addr = @family = nil
    if family == Socket::AF_UNSPEC || family == Socket::AF_INET
      @addr = in_addr(prefix)
      if @addr
        @family = Socket::AF_INET
      end
    end
    if !@addr && (family == Socket::AF_UNSPEC || family == Socket::AF_INET6)
      @addr = in6_addr(prefix)
      @family = Socket::AF_INET6
    end
    if family != Socket::AF_UNSPEC && @family != family
      raise AddressFamilyError, "address family mismatch"
    end
    if prefixlen
      mask!(prefixlen)
    else
      @mask_addr = (@family == Socket::AF_INET) ? IN4MASK : IN6MASK
    end
  end

  def coerce_other(other)
    case other
    when IPAddr
      other
    when String
      self.class.new(other)
    else
      self.class.new(other, @family)
    end
  end

  def in_addr(addr)
    case addr
    when Array
      octets = addr
    else
      m = RE_IPV4ADDRLIKE.match(addr) or return nil
      octets = m.captures
    end
    octets.inject(0) { |i, s|
      (n = s.to_i) < 256 or raise InvalidAddressError, "invalid address"
      s.match(/\A0./) and raise InvalidAddressError, "zero-filled number in IPv4 address is ambiguous"
      i << 8 | n
    }
  end

  def in6_addr(left)
    case left
    when RE_IPV6ADDRLIKE_FULL
      if $2
        addr = in_addr($~[2,4])
        left = $1 + ':'
      else
        addr = 0
      end
      right = ''
    when RE_IPV6ADDRLIKE_COMPRESSED
      if $4
        left.count(':') <= 6 or raise InvalidAddressError, "invalid address"
        addr = in_addr($~[4,4])
        left = $1
        right = $3 + '0:0'
      else
        left.count(':') <= ($1.empty? || $2.empty? ? 8 : 7) or
          raise InvalidAddressError, "invalid address"
        left = $1
        right = $2
        addr = 0
      end
    else
      raise InvalidAddressError, "invalid address"
    end
    l = left.split(':')
    r = right.split(':')
    rest = 8 - l.size - r.size
    if rest < 0
      return nil
    end
    (l + Array.new(rest, '0') + r).inject(0) { |i, s|
      i << 16 | s.hex
    } | addr
  end

  def addr_mask(addr)
    case @family
    when Socket::AF_INET
      return addr & IN4MASK
    when Socket::AF_INET6
      return addr & IN6MASK
    else
      raise AddressFamilyError, "unsupported address family"
    end
  end

  def _reverse
    case @family
    when Socket::AF_INET
      return (0..3).map { |i|
        (@addr >> (8 * i)) & 0xff
      }.join('.')
    when Socket::AF_INET6
      return ("%.32x" % @addr).reverse!.gsub!(/.(?!$)/, '\&.')
    else
      raise AddressFamilyError, "unsupported address family"
    end
  end

  def _to_string(addr)
    case @family
    when Socket::AF_INET
      return (0..3).map { |i|
        (addr >> (24 - 8 * i)) & 0xff
      }.join('.')
    when Socket::AF_INET6
      return (("%.32x" % addr).gsub!(/.{4}(?!$)/, '\&:'))
    else
      raise AddressFamilyError, "unsupported address family"
    end
  end

end

unless Socket.const_defined? :AF_INET6
  class Socket < BasicSocket
    AF_INET6 = Object.new
  end

  class << IPSocket
    private

    def valid_v6?(addr)
      case addr
      when IPAddr::RE_IPV6ADDRLIKE_FULL
        if $2
          $~[2,4].all? {|i| i.to_i < 256 }
        else
          true
        end
      when IPAddr::RE_IPV6ADDRLIKE_COMPRESSED
        if $4
          addr.count(':') <= 6 && $~[4,4].all? {|i| i.to_i < 256}
        else
          addr.count(':') <= 7
        end
      else
        false
      end
    end

    alias getaddress_orig getaddress

    public

    def getaddress(s)
      if valid_v6?(s)
        s
      else
        getaddress_orig(s)
      end
    end
  end
end
