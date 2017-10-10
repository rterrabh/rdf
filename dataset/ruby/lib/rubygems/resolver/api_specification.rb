
class Gem::Resolver::APISpecification < Gem::Resolver::Specification


  def initialize(set, api_data)
    super()

    @set = set
    @name = api_data[:name]
    @version = Gem::Version.new api_data[:number]
    @platform = Gem::Platform.new api_data[:platform]
    @dependencies = api_data[:dependencies].map do |name, ver|
      Gem::Dependency.new name, ver.split(/\s*,\s*/)
    end
  end

  def == other # :nodoc:
    self.class === other and
      @set          == other.set and
      @name         == other.name and
      @version      == other.version and
      @platform     == other.platform and
      @dependencies == other.dependencies
  end

  def fetch_development_dependencies # :nodoc:
    spec = source.fetch_spec Gem::NameTuple.new @name, @version, @platform

    @dependencies = spec.dependencies
  end

  def installable_platform? # :nodoc:
    Gem::Platform.match @platform
  end

  def pretty_print q # :nodoc:
    q.group 2, '[APISpecification', ']' do
      q.breakable
      q.text "name: #{name}"

      q.breakable
      q.text "version: #{version}"

      q.breakable
      q.text "platform: #{platform}"

      q.breakable
      q.text 'dependencies:'
      q.breakable
      q.pp @dependencies

      q.breakable
      q.text "set uri: #{@set.dep_uri}"
    end
  end


  def spec # :nodoc:
    @spec ||=
      begin
        tuple = Gem::NameTuple.new @name, @version, @platform

        source.fetch_spec tuple
      end
  end

  def source # :nodoc:
    @set.source
  end

end

