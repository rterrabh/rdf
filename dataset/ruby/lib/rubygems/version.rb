
class Gem::Version
  autoload :Requirement, 'rubygems/requirement'

  include Comparable

  VERSION_PATTERN = '[0-9]+(?>\.[0-9a-zA-Z]+)*(-[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?' # :nodoc:
  ANCHORED_VERSION_PATTERN = /\A\s*(#{VERSION_PATTERN})?\s*\z/ # :nodoc:


  def version
    @version.dup
  end

  alias to_s version


  def self.correct? version
    version.to_s =~ ANCHORED_VERSION_PATTERN
  end


  def self.create input
    if self === input then # check yourself before you wreck yourself
      input
    elsif input.nil? then
      nil
    else
      new input
    end
  end

  @@all = {}

  def self.new version # :nodoc:
    return super unless Gem::Version == self

    @@all[version] ||= super
  end


  def initialize version
    raise ArgumentError, "Malformed version number string #{version}" unless
      self.class.correct?(version)

    @version = version.to_s.strip.gsub("-",".pre.")
    @segments = nil
  end


  def bump
    segments = self.segments.dup
    segments.pop while segments.any? { |s| String === s }
    segments.pop if segments.size > 1

    segments[-1] = segments[-1].succ
    self.class.new segments.join(".")
  end


  def eql? other
    self.class === other and @version == other.version
  end

  def hash # :nodoc:
    @hash ||= segments.hash
  end

  def init_with coder # :nodoc:
    yaml_initialize coder.tag, coder.map
  end

  def inspect # :nodoc:
    "#<#{self.class} #{version.inspect}>"
  end


  def marshal_dump
    [version]
  end


  def marshal_load array
    initialize array[0]
  end

  def yaml_initialize(tag, map) # :nodoc:
    @version = map['version']
    @segments = nil
    @hash = nil
  end

  def to_yaml_properties # :nodoc:
    ["@version"]
  end

  def encode_with coder # :nodoc:
    coder.add 'version', @version
  end


  def prerelease?
    @prerelease ||= !!(@version =~ /[a-zA-Z]/)
  end

  def pretty_print q # :nodoc:
    q.text "Gem::Version.new(#{version.inspect})"
  end


  def release
    return self unless prerelease?

    segments = self.segments.dup
    segments.pop while segments.any? { |s| String === s }
    self.class.new segments.join('.')
  end

  def segments # :nodoc:


    @segments ||= @version.scan(/[0-9]+|[a-z]+/i).map do |s|
      /^\d+$/ =~ s ? s.to_i : s
    end
  end


  def approximate_recommendation
    segments = self.segments.dup

    segments.pop    while segments.any? { |s| String === s }
    segments.pop    while segments.size > 2
    segments.push 0 while segments.size < 2

    "~> #{segments.join(".")}"
  end


  def <=> other
    return unless Gem::Version === other
    return 0 if @version == other.version

    lhsegments = segments
    rhsegments = other.segments

    lhsize = lhsegments.size
    rhsize = rhsegments.size
    limit  = (lhsize > rhsize ? lhsize : rhsize) - 1

    i = 0

    while i <= limit
      lhs, rhs = lhsegments[i] || 0, rhsegments[i] || 0
      i += 1

      next      if lhs == rhs
      return -1 if String  === lhs && Numeric === rhs
      return  1 if Numeric === lhs && String  === rhs

      return lhs <=> rhs
    end

    return 0
  end
end
