
class Gem::Resolver::LockSet < Gem::Resolver::Set

  attr_reader :specs # :nodoc:


  def initialize sources
    super()

    @sources = sources.map do |source|
      Gem::Source::Lock.new source
    end

    @specs   = []
  end


  def add name, version, platform # :nodoc:
    version = Gem::Version.new version

    specs = @sources.map do |source|
      Gem::Resolver::LockSpecification.new self, name, version, source,
                                           platform
    end

    @specs.concat specs

    specs
  end


  def find_all req
    @specs.select do |spec|
      req.match? spec
    end
  end


  def load_spec name, version, platform, source # :nodoc:
    dep = Gem::Dependency.new name, version

    found = @specs.find do |spec|
      dep.matches_spec? spec and spec.platform == platform
    end

    tuple = Gem::NameTuple.new found.name, found.version, found.platform

    found.source.fetch_spec tuple
  end

  def pretty_print q # :nodoc:
    q.group 2, '[LockSet', ']' do
      q.breakable
      q.text 'source:'

      q.breakable
      q.pp @source

      q.breakable
      q.text 'specs:'

      q.breakable
      q.pp @specs.map { |spec| spec.full_name }
    end
  end

end

