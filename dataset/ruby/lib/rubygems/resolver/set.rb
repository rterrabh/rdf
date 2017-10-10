
class Gem::Resolver::Set


  attr_accessor :remote


  attr_accessor :errors


  attr_accessor :prerelease

  def initialize # :nodoc:
    @prerelease = false
    @remote     = true
    @errors     = []
  end


  def find_all req
    raise NotImplementedError
  end


  def prefetch reqs
  end


  def remote? # :nodoc:
    @remote
  end

end

