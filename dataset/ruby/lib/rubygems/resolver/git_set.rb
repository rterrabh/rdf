
class Gem::Resolver::GitSet < Gem::Resolver::Set


  attr_accessor :root_dir


  attr_reader :need_submodules # :nodoc:


  attr_reader :repositories # :nodoc:


  attr_reader :specs # :nodoc:

  def initialize # :nodoc:
    super()

    @git             = ENV['git'] || 'git'
    @need_submodules = {}
    @repositories    = {}
    @root_dir        = Gem.dir
    @specs           = {}
  end

  def add_git_gem name, repository, reference, submodules # :nodoc:
    @repositories[name] = [repository, reference]
    @need_submodules[repository] = submodules
  end


  def add_git_spec name, version, repository, reference, submodules # :nodoc:
    add_git_gem name, repository, reference, submodules

    source = Gem::Source::Git.new name, repository, reference
    source.root_dir = @root_dir

    spec = Gem::Specification.new do |s|
      s.name    = name
      s.version = version
    end

    git_spec = Gem::Resolver::GitSpecification.new self, spec, source

    @specs[spec.name] = git_spec

    git_spec
  end


  def find_all req
    prefetch nil

    specs.values.select do |spec|
      req.match? spec
    end
  end


  def prefetch reqs
    return unless @specs.empty?

    @repositories.each do |name, (repository, reference)|
      source = Gem::Source::Git.new name, repository, reference
      source.root_dir = @root_dir
      source.remote = @remote

      source.specs.each do |spec|
        git_spec = Gem::Resolver::GitSpecification.new self, spec, source

        @specs[spec.name] = git_spec
      end
    end
  end

  def pretty_print q # :nodoc:
    q.group 2, '[GitSet', ']' do
      next if @repositories.empty?
      q.breakable

      repos = @repositories.map do |name, (repository, reference)|
        "#{name}: #{repository}@#{reference}"
      end

      q.seplist repos do |repo|
        q.text repo
      end
    end
  end

end

