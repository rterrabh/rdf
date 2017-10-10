
class Gem::Source::Vendor < Gem::Source::Installed


  def initialize path
    @uri = path
  end

  def <=> other
    case other
    when Gem::Source::Lock then
      -1
    when Gem::Source::Vendor then
      0
    when Gem::Source then
      1
    else
      nil
    end
  end

end

