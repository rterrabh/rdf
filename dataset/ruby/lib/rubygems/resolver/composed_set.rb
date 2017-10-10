
class Gem::Resolver::ComposedSet < Gem::Resolver::Set

  attr_reader :sets # :nodoc:


  def initialize *sets
    super()

    @sets = sets
  end


  def prerelease= allow_prerelease
    super

    sets.each do |set|
      set.prerelease = allow_prerelease
    end
  end


  def remote= remote
    super

    @sets.each { |set| set.remote = remote }
  end

  def errors
    @errors + @sets.map { |set| set.errors }.flatten
  end


  def find_all req
    @sets.map do |s|
      s.find_all req
    end.flatten
  end


  def prefetch reqs
    @sets.each { |s| s.prefetch(reqs) }
  end

end

