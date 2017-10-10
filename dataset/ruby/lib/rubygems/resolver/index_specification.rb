
class Gem::Resolver::IndexSpecification < Gem::Resolver::Specification


  def initialize set, name, version, source, platform
    super()

    @set = set
    @name = name
    @version = version
    @source = source
    @platform = platform.to_s

    @spec = nil
  end


  def dependencies
    spec.dependencies
  end

  def inspect # :nodoc:
    '#<%s %s source %s>' % [self.class, full_name, @source]
  end

  def pretty_print q # :nodoc:
    q.group 2, '[Index specification', ']' do
      q.breakable
      q.text full_name

      unless Gem::Platform::RUBY == @platform then
        q.breakable
        q.text @platform.to_s
      end

      q.breakable
      q.text 'source '
      q.pp @source
    end
  end


  def spec # :nodoc:
    @spec ||=
      begin
        tuple = Gem::NameTuple.new @name, @version, @platform

        @source.fetch_spec tuple
      end
  end

end

