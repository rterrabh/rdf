
require "rubygems/requirement"

class Gem::Dependency


  TYPES = [
    :development,
    :runtime,
  ]


  attr_accessor :name


  attr_writer :prerelease


  def initialize name, *requirements
    case name
    when String then # ok
    when Regexp then
      msg = ["NOTE: Dependency.new w/ a regexp is deprecated.",
             "Dependency.new called from #{Gem.location_of_caller.join(":")}"]
      warn msg.join("\n") unless Gem::Deprecate.skip
    else
      raise ArgumentError,
            "dependency name must be a String, was #{name.inspect}"
    end

    type         = Symbol === requirements.last ? requirements.pop : :runtime
    requirements = requirements.first if 1 == requirements.length # unpack

    unless TYPES.include? type
      raise ArgumentError, "Valid types are #{TYPES.inspect}, " +
                           "not #{type.inspect}"
    end

    @name        = name
    @requirement = Gem::Requirement.create requirements
    @type        = type
    @prerelease  = false


    @version_requirements = @requirement
  end


  def hash # :nodoc:
    name.hash ^ type.hash ^ requirement.hash
  end

  def inspect # :nodoc:
    if prerelease? then
      "<%s type=%p name=%p requirements=%p prerelease=ok>" %
        [self.class, self.type, self.name, requirement.to_s]
    else
      "<%s type=%p name=%p requirements=%p>" %
        [self.class, self.type, self.name, requirement.to_s]
    end
  end


  def prerelease?
    @prerelease || requirement.prerelease?
  end


  def latest_version?
    @requirement.none?
  end

  def pretty_print q # :nodoc:
    q.group 1, 'Gem::Dependency.new(', ')' do
      q.pp name
      q.text ','
      q.breakable

      q.pp requirement

      q.text ','
      q.breakable

      q.pp type
    end
  end


  def requirement
    return @requirement if defined?(@requirement) and @requirement



    if defined?(@version_requirement) && @version_requirement
      #nodyna <instance_variable_get-2247> <IVG COMPLEX (private access)>
      version = @version_requirement.instance_variable_get :@version
      @version_requirement  = nil
      @version_requirements = Gem::Requirement.new version
    end

    @requirement = @version_requirements if defined?(@version_requirements)
  end

  def requirements_list
    requirement.as_list
  end

  def to_s # :nodoc:
    if type != :runtime then
      "#{name} (#{requirement}, #{type})"
    else
      "#{name} (#{requirement})"
    end
  end


  def type
    @type ||= :runtime
  end

  def == other # :nodoc:
    Gem::Dependency === other &&
      self.name        == other.name &&
      self.type        == other.type &&
      self.requirement == other.requirement
  end


  def <=> other
    self.name <=> other.name
  end


  def =~ other
    unless Gem::Dependency === other
      return unless other.respond_to?(:name) && other.respond_to?(:version)
      other = Gem::Dependency.new other.name, other.version
    end

    return false unless name === other.name

    reqs = other.requirement.requirements

    return false unless reqs.length == 1
    return false unless reqs.first.first == '='

    version = reqs.first.last

    requirement.satisfied_by? version
  end

  alias === =~


  def match? obj, version=nil, allow_prerelease=false
    if !version
      name = obj.name
      version = obj.version
    else
      name = obj
    end

    return false unless self.name === name

    version = Gem::Version.new version

    return true if requirement.none? and not version.prerelease?
    return false if version.prerelease? and
                    not allow_prerelease and
                    not prerelease?

    requirement.satisfied_by? version
  end


  def matches_spec? spec
    return false unless name === spec.name
    return true  if requirement.none?

    requirement.satisfied_by?(spec.version)
  end


  def merge other
    unless name == other.name then
      raise ArgumentError,
            "#{self} and #{other} have different names"
    end

    default = Gem::Requirement.default
    self_req  = self.requirement
    other_req = other.requirement

    return self.class.new name, self_req  if other_req == default
    return self.class.new name, other_req if self_req  == default

    self.class.new name, self_req.as_list.concat(other_req.as_list)
  end

  def matching_specs platform_only = false
    matches = Gem::Specification.stubs.find_all { |spec|
      self.name === spec.name and # TODO: == instead of ===
        requirement.satisfied_by? spec.version
    }.map(&:to_spec)

    if platform_only
      matches.reject! { |spec|
        not Gem::Platform.match spec.platform
      }
    end

    matches.sort_by { |s| s.sort_obj } # HACK: shouldn't be needed
  end


  def specific?
    @requirement.specific?
  end

  def to_specs
    matches = matching_specs true


    if matches.empty? then
      specs = Gem::Specification.find_all { |s|
                s.name == name
              }.map { |x| x.full_name }

      if specs.empty?
        total = Gem::Specification.to_a.size
        msg   = "Could not find '#{name}' (#{requirement}) among #{total} total gem(s)\n"
      else
        msg   = "Could not find '#{name}' (#{requirement}) - did find: [#{specs.join ','}]\n"
      end
      msg << "Checked in 'GEM_PATH=#{Gem.path.join(File::PATH_SEPARATOR)}', execute `gem env` for more information"

      error = Gem::LoadError.new(msg)
      error.name        = self.name
      error.requirement = self.requirement
      raise error
    end


    matches
  end

  def to_spec
    matches = self.to_specs

    active = matches.find { |spec| spec.activated? }

    return active if active

    matches.delete_if { |spec| spec.version.prerelease? } unless prerelease?

    matches.last
  end
end
