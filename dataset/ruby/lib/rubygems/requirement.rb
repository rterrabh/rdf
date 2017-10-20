require "rubygems/version"
require "rubygems/deprecate"

Gem.load_yaml if defined? ::YAML


class Gem::Requirement
  OPS = { #:nodoc:
    "="  =>  lambda { |v, r| v == r },
    "!=" =>  lambda { |v, r| v != r },
    ">"  =>  lambda { |v, r| v >  r },
    "<"  =>  lambda { |v, r| v <  r },
    ">=" =>  lambda { |v, r| v >= r },
    "<=" =>  lambda { |v, r| v <= r },
    "~>" =>  lambda { |v, r| v >= r && v.release < r.bump }
  }

  quoted  = OPS.keys.map { |k| Regexp.quote k }.join "|"
  PATTERN_RAW = "\\s*(#{quoted})?\\s*(#{Gem::Version::VERSION_PATTERN})\\s*" # :nodoc:


  PATTERN = /\A#{PATTERN_RAW}\z/


  DefaultRequirement = [">=", Gem::Version.new(0)]


  class BadRequirementError < ArgumentError; end


  def self.create input
    case input
    when Gem::Requirement then
      input
    when Gem::Version, Array then
      new input
    else
      if input.respond_to? :to_str then
        new [input.to_str]
      else
        default
      end
    end
  end


  def self.default
    new '>= 0'
  end


  def self.parse obj
    return ["=", obj] if Gem::Version === obj

    unless PATTERN =~ obj.to_s
      raise BadRequirementError, "Illformed requirement [#{obj.inspect}]"
    end

    if $1 == ">=" && $2 == "0"
      DefaultRequirement
    else
      [$1 || "=", Gem::Version.new($2)]
    end
  end


  attr_reader :requirements #:nodoc:


  def initialize *requirements
    requirements = requirements.flatten
    requirements.compact!
    requirements.uniq!

    if requirements.empty?
      @requirements = [DefaultRequirement]
    else
      @requirements = requirements.map! { |r| self.class.parse r }
    end
  end


  def concat new
    new = new.flatten
    new.compact!
    new.uniq!
    new = new.map { |r| self.class.parse r }

    @requirements.concat new
  end


  def for_lockfile # :nodoc:
    return if [DefaultRequirement] == @requirements

    list = requirements.sort_by { |_, version|
      version
    }.map { |op, version|
      "#{op} #{version}"
    }.uniq

    " (#{list.join ', '})"
  end


  def none?
    if @requirements.size == 1
      @requirements[0] == DefaultRequirement
    else
      false
    end
  end


  def exact?
    return false unless @requirements.size == 1
    @requirements[0][0] == "="
  end

  def as_list # :nodoc:
    requirements.map { |op, version| "#{op} #{version}" }.sort
  end

  def hash # :nodoc:
    requirements.hash
  end

  def marshal_dump # :nodoc:
    fix_syck_default_key_in_requirements

    [@requirements]
  end

  def marshal_load array # :nodoc:
    @requirements = array[0]

    fix_syck_default_key_in_requirements
  end

  def yaml_initialize(tag, vals) # :nodoc:
    vals.each do |ivar, val|
      #nodyna <instance_variable_set-2330> <IVS COMPLEX (array)>
      instance_variable_set "@#{ivar}", val
    end

    Gem.load_yaml
    fix_syck_default_key_in_requirements
  end

  def init_with coder # :nodoc:
    yaml_initialize coder.tag, coder.map
  end

  def to_yaml_properties # :nodoc:
    ["@requirements"]
  end

  def encode_with coder # :nodoc:
    coder.add 'requirements', @requirements
  end


  def prerelease?
    requirements.any? { |r| r.last.prerelease? }
  end

  def pretty_print q # :nodoc:
    q.group 1, 'Gem::Requirement.new(', ')' do
      q.pp as_list
    end
  end


  def satisfied_by? version
    raise ArgumentError, "Need a Gem::Version: #{version.inspect}" unless
      Gem::Version === version
    requirements.all? { |op, rv| (OPS[op] || OPS["="]).call version, rv }
  end

  alias :=== :satisfied_by?
  alias :=~ :satisfied_by?


  def specific?
    return true if @requirements.length > 1 # GIGO, > 1, > 2 is silly

    not %w[> >=].include? @requirements.first.first # grab the operator
  end

  def to_s # :nodoc:
    as_list.join ", "
  end

  def == other # :nodoc:
    Gem::Requirement === other and to_s == other.to_s
  end

  private

  def fix_syck_default_key_in_requirements # :nodoc:
    Gem.load_yaml

    @requirements.each do |r|
      if r[0].kind_of? Gem::SyckDefaultKey
        r[0] = "="
      end
    end
  end
end

class Gem::Version

  Requirement = Gem::Requirement # :nodoc:
end
