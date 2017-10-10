
class Gem::Source::Installed < Gem::Source

  def initialize # :nodoc:
    @uri = nil
  end


  def <=> other
    case other
    when Gem::Source::Git,
         Gem::Source::Lock,
         Gem::Source::Vendor then
      -1
    when Gem::Source::Installed then
      0
    when Gem::Source then
      1
    else
      nil
    end
  end


  def download spec, path
    nil
  end

  def pretty_print q # :nodoc:
    q.text '[Installed]'
  end

end

