
class Gem::Resolver::VendorSpecification < Gem::Resolver::SpecSpecification

  def == other # :nodoc:
    self.class === other and
      @set  == other.set and
      @spec == other.spec and
      @source == other.source
  end


  def install options = {}
    yield nil
  end

end

