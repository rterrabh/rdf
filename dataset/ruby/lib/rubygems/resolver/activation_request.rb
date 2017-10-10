
class Gem::Resolver::ActivationRequest


  attr_reader :request


  attr_reader :spec


  def initialize spec, request, others_possible = true
    @spec = spec
    @request = request
    @others_possible = others_possible
  end

  def == other # :nodoc:
    case other
    when Gem::Specification
      @spec == other
    when Gem::Resolver::ActivationRequest
      @spec == other.spec && @request == other.request
    else
      false
    end
  end


  def development?
    @request.development?
  end


  def download path
    if @spec.respond_to? :source
      source = @spec.source
    else
      source = Gem.sources.first
    end

    Gem.ensure_gem_subdirectories path

    source.download full_spec, path
  end


  def full_name
    @spec.full_name
  end


  def full_spec
    Gem::Specification === @spec ? @spec : @spec.spec
  end

  def inspect # :nodoc:
    others =
      case @others_possible
      when true then # TODO remove at RubyGems 3
        ' (others possible)'
      when false then # TODO remove at RubyGems 3
        nil
      else
        unless @others_possible.empty? then
          others = @others_possible.map { |s| s.full_name }
          " (others possible: #{others.join ', '})"
        end
      end

    '#<%s for %p from %s%s>' % [
      self.class, @spec, @request, others
    ]
  end


  def installed?
    case @spec
    when Gem::Resolver::VendorSpecification then
      true
    else
      this_spec = full_spec

      Gem::Specification.any? do |s|
        s == this_spec
      end
    end
  end


  def name
    @spec.name
  end


  def others_possible?
    case @others_possible
    when true, false then
      @others_possible
    else
      not @others_possible.empty?
    end
  end


  def parent
    @request.requester
  end

  def pretty_print q # :nodoc:
    q.group 2, '[Activation request', ']' do
      q.breakable
      q.pp @spec

      q.breakable
      q.text ' for '
      q.pp @request

      case @others_possible
      when false then
      when true then
        q.breakable
        q.text 'others possible'
      else
        unless @others_possible.empty? then
          q.breakable
          q.text 'others '
          q.pp @others_possible.map { |s| s.full_name }
        end
      end
    end
  end


  def version
    @spec.version
  end

end

