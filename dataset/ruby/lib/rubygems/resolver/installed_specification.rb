
class Gem::Resolver::InstalledSpecification < Gem::Resolver::SpecSpecification

  def == other # :nodoc:
    self.class === other and
      @set  == other.set and
      @spec == other.spec
  end


  def install options = {}
    yield nil
  end


  def installable_platform?
    return true if @source.kind_of? Gem::Source::SpecificFile

    super
  end

  def pretty_print q # :nodoc:
    q.group 2, '[InstalledSpecification', ']' do
      q.breakable
      q.text "name: #{name}"

      q.breakable
      q.text "version: #{version}"

      q.breakable
      q.text "platform: #{platform}"

      q.breakable
      q.text 'dependencies:'
      q.breakable
      q.pp spec.dependencies
    end
  end


  def source
    @source ||= Gem::Source::Installed.new
  end

end

