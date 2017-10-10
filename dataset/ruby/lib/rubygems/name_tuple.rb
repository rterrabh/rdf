
require 'rubygems/platform'

class Gem::NameTuple
  def initialize(name, version, platform="ruby")
    @name = name
    @version = version

    unless platform.kind_of? Gem::Platform
      platform = "ruby" if !platform or platform.empty?
    end

    @platform = platform
  end

  attr_reader :name, :version, :platform


  def self.from_list list
    list.map { |t| new(*t) }
  end


  def self.to_basic list
    list.map { |t| t.to_a }
  end


  def self.null
    new nil, Gem::Version.new(0), nil
  end


  def full_name
    case @platform
    when nil, 'ruby', ''
      "#{@name}-#{@version}"
    else
      "#{@name}-#{@version}-#{@platform}"
    end.untaint
  end


  def match_platform?
    Gem::Platform.match @platform
  end

  def prerelease?
    @version.prerelease?
  end


  def spec_name
    "#{full_name}.gemspec"
  end


  def to_a
    [@name, @version, @platform]
  end

  def inspect # :nodoc:
    "#<Gem::NameTuple #{@name}, #{@version}, #{@platform}>"
  end

  alias to_s inspect # :nodoc:

  def <=> other
    [@name, @version, @platform == Gem::Platform::RUBY ? -1 : 1] <=>
      [other.name, other.version,
       other.platform == Gem::Platform::RUBY ? -1 : 1]
  end

  include Comparable


  def == other
    case other
    when self.class
      @name == other.name and
        @version == other.version and
        @platform == other.platform
    when Array
      to_a == other
    else
      false
    end
  end

  alias_method :eql?, :==

  def hash
    to_a.hash
  end

end
