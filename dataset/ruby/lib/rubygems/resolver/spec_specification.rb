
class Gem::Resolver::SpecSpecification < Gem::Resolver::Specification


  def initialize set, spec, source = nil
    @set    = set
    @source = source
    @spec   = spec
  end


  def dependencies
    spec.dependencies
  end


  def full_name
    "#{spec.name}-#{spec.version}"
  end


  def name
    spec.name
  end


  def platform
    spec.platform
  end


  def version
    spec.version
  end

end

