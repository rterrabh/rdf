class Version
  include Comparable

  class Token
    include Comparable

    attr_reader :value

    def initialize(value)
      @value = value
    end

    def inspect
      "#<#{self.class.name} #{value.inspect}>"
    end

    def to_s
      value.to_s
    end

    def numeric?
      false
    end
  end

  class NullToken < Token
    def initialize(value = nil)
      super
    end

    def <=>(other)
      case other
      when NullToken
        0
      when NumericToken
        other.value == 0 ? 0 : -1
      when AlphaToken, BetaToken, RCToken
        1
      else
        -1
      end
    end

    def inspect
      "#<#{self.class.name}>"
    end
  end

  NULL_TOKEN = NullToken.new

  class StringToken < Token
    PATTERN = /[a-z]+[0-9]*/i

    def initialize(value)
      @value = value.to_s
    end

    def <=>(other)
      case other
      when StringToken
        value <=> other.value
      when NumericToken, NullToken
        -Integer(other <=> self)
      end
    end
  end

  class NumericToken < Token
    PATTERN = /[0-9]+/i

    def initialize(value)
      @value = value.to_i
    end

    def <=>(other)
      case other
      when NumericToken
        value <=> other.value
      when StringToken
        1
      when NullToken
        -Integer(other <=> self)
      end
    end

    def numeric?
      true
    end
  end

  class CompositeToken < StringToken
    def rev
      value[/[0-9]+/].to_i
    end
  end

  class AlphaToken < CompositeToken
    PATTERN = /a(?:lpha)?[0-9]*/i

    def <=>(other)
      case other
      when AlphaToken
        rev <=> other.rev
      else
        super
      end
    end
  end

  class BetaToken < CompositeToken
    PATTERN = /b(?:eta)?[0-9]*/i

    def <=>(other)
      case other
      when BetaToken
        rev <=> other.rev
      when AlphaToken
        1
      when RCToken, PatchToken
        -1
      else
        super
      end
    end
  end

  class RCToken < CompositeToken
    PATTERN = /rc[0-9]*/i

    def <=>(other)
      case other
      when RCToken
        rev <=> other.rev
      when AlphaToken, BetaToken
        1
      when PatchToken
        -1
      else
        super
      end
    end
  end

  class PatchToken < CompositeToken
    PATTERN = /p[0-9]*/i

    def <=>(other)
      case other
      when PatchToken
        rev <=> other.rev
      when AlphaToken, BetaToken, RCToken
        1
      else
        super
      end
    end
  end

  SCAN_PATTERN = Regexp.union(
    AlphaToken::PATTERN,
    BetaToken::PATTERN,
    RCToken::PATTERN,
    PatchToken::PATTERN,
    NumericToken::PATTERN,
    StringToken::PATTERN
  )

  class FromURL < Version
    def detected_from_url?
      true
    end
  end

  def self.detect(url, specs)
    if specs.key?(:tag)
      FromURL.new(specs[:tag][/((?:\d+\.)*\d+)/, 1])
    else
      FromURL.parse(url)
    end
  end

  def initialize(val)
    if val.respond_to?(:to_str)
      @version = val.to_str
    else
      raise TypeError, "Version value must be a string"
    end
  end

  def detected_from_url?
    false
  end

  def head?
    version == "HEAD"
  end

  def <=>(other)
    return unless Version === other
    return 0 if version == other.version
    return 1 if head? && !other.head?
    return -1 if !head? && other.head?

    ltokens = tokens
    rtokens = other.tokens
    max = max(ltokens.length, rtokens.length)
    l = r = 0

    while l < max
      a = ltokens[l] || NULL_TOKEN
      b = rtokens[r] || NULL_TOKEN

      if a == b
        l += 1
        r += 1
        next
      elsif a.numeric? && b.numeric?
        return a <=> b
      elsif a.numeric?
        return 1 if a > NULL_TOKEN
        l += 1
      elsif b.numeric?
        return -1 if b > NULL_TOKEN
        r += 1
      else
        return a <=> b
      end
    end

    0
  end
  alias_method :eql?, :==

  def hash
    version.hash
  end

  def to_s
    version.dup
  end
  alias_method :to_str, :to_s

  protected

  attr_reader :version

  def tokens
    @tokens ||= tokenize
  end

  private

  def max(a, b)
    a > b ? a : b
  end

  def tokenize
    version.scan(SCAN_PATTERN).map! do |token|
      case token
      when /\A#{AlphaToken::PATTERN}\z/o   then AlphaToken
      when /\A#{BetaToken::PATTERN}\z/o    then BetaToken
      when /\A#{RCToken::PATTERN}\z/o      then RCToken
      when /\A#{PatchToken::PATTERN}\z/o   then PatchToken
      when /\A#{NumericToken::PATTERN}\z/o then NumericToken
      when /\A#{StringToken::PATTERN}\z/o  then StringToken
      end.new(token)
    end
  end

  def self.parse(spec)
    version = _parse(spec)
    new(version) unless version.nil?
  end

  def self._parse(spec)
    spec = Pathname.new(spec) unless spec.is_a? Pathname

    spec_s = spec.to_s

    stem = if spec.directory?
      spec.basename.to_s
    elsif %r{((?:sourceforge.net|sf.net)/.*)/download$}.match(spec_s)
      Pathname.new(spec.dirname).stem
    else
      spec.stem
    end

    m = %r{github.com/.+/(?:zip|tar)ball/(?:v|\w+-)?((?:\d+[-._])+\d*)$}.match(spec_s)
    return m.captures.first unless m.nil?

    m = /[-_]([Rr]\d+[AaBb]\d*(?:-\d+)?)/.match(spec_s)
    return m.captures.first unless m.nil?

    m = /((?:\d+_)+\d+)$/.match(stem)
    return m.captures.first.tr("_", ".") unless m.nil?

    m = /[-_]((?:\d+\.)*\d\.\d+-(?:p|rc|RC)?\d+)(?:[-._](?:bin|dist|stable|src|sources))?$/.match(stem)
    return m.captures.first unless m.nil?

    m = /-((?:\d)+-\d)/.match(stem)
    return m.captures.first unless m.nil?

    m = /-((?:\d+\.)*\d+)$/.match(stem)
    return m.captures.first unless m.nil?

    m = /-((?:\d+\.)*\d+(?:[abc]|rc|RC)\d*)$/.match(stem)
    return m.captures.first unless m.nil?

    m = /-((?:\d+\.)*\d+-beta\d*)$/.match(stem)
    return m.captures.first unless m.nil?

    m = /-(\d+\.\d+(?:\.\d+)?)-w(?:in)?(?:32|64)$/.match(stem)
    return m.captures.first unless m.nil?

    m = /[-_](\d+\.\d+(?:\.\d+)?(?:-\d+)?)[-_.](?:i[36]86|x86|x64(?:[-_](?:32|64))?)$/.match(stem)
    return m.captures.first unless m.nil?

    m = /((?:\d+\.)*\d+)$/.match(stem)
    return m.captures.first unless m.nil?

    m = /-((?:\d+\.)+\d+[abc]?)[-._](?:bin|dist|stable|src|sources?)$/.match(stem)
    return m.captures.first unless m.nil?

    m = /_((?:\d+\.)+\d+[abc]?)[.]orig$/.match(stem)
    return m.captures.first unless m.nil?

    m = /-v?([^-]+)/.match(stem)
    return m.captures.first unless m.nil?

    m = /_([^_]+)/.match(stem)
    return m.captures.first unless m.nil?

    m = /\/(\d\.\d+(\.\d)?)\//.match(spec_s)
    return m.captures.first unless m.nil?

    m = /\.v(\d+[a-z]?)/.match(stem)
    return m.captures.first unless m.nil?
  end
end
