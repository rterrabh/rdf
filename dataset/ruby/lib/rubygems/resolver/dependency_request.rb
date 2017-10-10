
class Gem::Resolver::DependencyRequest


  attr_reader :dependency


  attr_reader :requester


  def initialize dependency, requester
    @dependency = dependency
    @requester  = requester
  end

  def == other # :nodoc:
    case other
    when Gem::Dependency
      @dependency == other
    when Gem::Resolver::DependencyRequest
      @dependency == other.dependency && @requester == other.requester
    else
      false
    end
  end


  def development?
    @dependency.type == :development
  end


  def match? spec, allow_prerelease = false
    @dependency.match? spec, nil, allow_prerelease
  end


  def matches_spec?(spec)
    @dependency.matches_spec? spec
  end


  def name
    @dependency.name
  end


  def explicit?
    @requester.nil?
  end


  def implicit?
    !explicit?
  end


  def request_context
    @requester ? @requester.request : "(unknown)"
  end

  def pretty_print q # :nodoc:
    q.group 2, '[Dependency request ', ']' do
      q.breakable
      q.text @dependency.to_s

      q.breakable
      q.text ' requested by '
      q.pp @requester
    end
  end


  def requirement
    @dependency.requirement
  end

  def to_s # :nodoc:
    @dependency.to_s
  end

end

