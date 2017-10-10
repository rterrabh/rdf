
class Gem::Resolver::CurrentSet < Gem::Resolver::Set

  def find_all req
    req.dependency.matching_specs
  end

end

