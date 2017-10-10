
class Gem::Source::SpecificFile < Gem::Source


  attr_reader :path


  def initialize(file)
    @uri = nil
    @path = ::File.expand_path(file)

    @package = Gem::Package.new @path
    @spec = @package.spec
    @name = @spec.name_tuple
  end


  attr_reader :spec

  def load_specs *a # :nodoc:
    [@name]
  end

  def fetch_spec name # :nodoc:
    return @spec if name == @name
    raise Gem::Exception, "Unable to find '#{name}'"
    @spec
  end

  def download spec, dir = nil # :nodoc:
    return @path if spec == @spec
    raise Gem::Exception, "Unable to download '#{spec.full_name}'"
  end

  def pretty_print q # :nodoc:
    q.group 2, '[SpecificFile:', ']' do
      q.breakable
      q.text @path
    end
  end


  def <=> other
    case other
    when Gem::Source::SpecificFile then
      return nil if @spec.name != other.spec.name

      @spec.version <=> other.spec.version
    else
      super
    end
  end

end
