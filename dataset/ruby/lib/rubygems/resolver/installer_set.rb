
class Gem::Resolver::InstallerSet < Gem::Resolver::Set


  attr_reader :always_install # :nodoc:


  attr_accessor :ignore_dependencies # :nodoc:


  attr_accessor :ignore_installed # :nodoc:


  attr_reader :remote_set # :nodoc:


  def initialize domain
    super()

    @domain = domain
    @remote = consider_remote?

    @f = Gem::SpecFetcher.fetcher

    @always_install      = []
    @ignore_dependencies = false
    @ignore_installed    = false
    @local               = {}
    @remote_set          = Gem::Resolver::BestSet.new
    @specs               = {}
  end


  def add_always_install dependency
    request = Gem::Resolver::DependencyRequest.new dependency, nil

    found = find_all request

    found.delete_if { |s|
      s.version.prerelease? and not s.local?
    } unless dependency.prerelease?

    found = found.select do |s|
      Gem::Source::SpecificFile === s.source or
        Gem::Platform::RUBY == s.platform or
        Gem::Platform.local === s.platform
    end

    if found.empty? then
      exc = Gem::UnsatisfiableDependencyError.new request
      exc.errors = errors

      raise exc
    end

    newest = found.max_by do |s|
      [s.version, s.platform == Gem::Platform::RUBY ? -1 : 1]
    end

    @always_install << newest.spec
  end


  def add_local dep_name, spec, source
    @local[dep_name] = [spec, source]
  end


  def consider_local? # :nodoc:
    @domain == :both or @domain == :local
  end


  def consider_remote? # :nodoc:
    @domain == :both or @domain == :remote
  end


  def errors
    @errors + @remote_set.errors
  end


  def find_all req
    res = []

    dep  = req.dependency

    return res if @ignore_dependencies and
              @always_install.none? { |spec| dep.match? spec }

    name = dep.name

    dep.matching_specs.each do |gemspec|
      next if @always_install.any? { |spec| spec.name == gemspec.name }

      res << Gem::Resolver::InstalledSpecification.new(self, gemspec)
    end unless @ignore_installed

    if consider_local? then
      matching_local = @local.values.select do |spec, _|
        req.match? spec
      end.map do |spec, source|
        Gem::Resolver::LocalSpecification.new self, spec, source
      end

      res.concat matching_local

      local_source = Gem::Source::Local.new

      if local_spec = local_source.find_gem(name, dep.requirement) then
        res << Gem::Resolver::IndexSpecification.new(
          self, local_spec.name, local_spec.version,
          local_source, local_spec.platform)
      end
    end

    res.delete_if do |spec|
      spec.version.prerelease? and not dep.prerelease?
    end

    res.concat @remote_set.find_all req if consider_remote?

    res
  end

  def prefetch(reqs)
    @remote_set.prefetch(reqs) if consider_remote?
  end

  def prerelease= allow_prerelease
    super

    @remote_set.prerelease = allow_prerelease
  end

  def inspect # :nodoc:
    always_install = @always_install.map { |s| s.full_name }

    '#<%s domain: %s specs: %p always install: %p>' % [
      self.class, @domain, @specs.keys, always_install,
    ]
  end


  def load_spec name, ver, platform, source # :nodoc:
    key = "#{name}-#{ver}-#{platform}"

    @specs.fetch key do
      tuple = Gem::NameTuple.new name, ver, platform

      @specs[key] = source.fetch_spec tuple
    end
  end


  def local? dep_name # :nodoc:
    spec, = @local[dep_name]

    spec
  end

  def pretty_print q # :nodoc:
    q.group 2, '[InstallerSet', ']' do
      q.breakable
      q.text "domain: #{@domain}"

      q.breakable
      q.text 'specs: '
      q.pp @specs.keys

      q.breakable
      q.text 'always install: '
      q.pp @always_install
    end
  end

  def remote= remote # :nodoc:
    case @domain
    when :local then
      @domain = :both if remote
    when :remote then
      @domain = nil unless remote
    when :both then
      @domain = :local unless remote
    end
  end

end

