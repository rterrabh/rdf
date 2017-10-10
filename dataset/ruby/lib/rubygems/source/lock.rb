
class Gem::Source::Lock < Gem::Source


  attr_reader :wrapped


  def initialize source
    @wrapped = source
  end

  def <=> other # :nodoc:
    case other
    when Gem::Source::Lock then
      @wrapped <=> other.wrapped
    when Gem::Source then
      1
    else
      nil
    end
  end

  def == other # :nodoc:
    0 == (self <=> other)
  end


  def fetch_spec name_tuple
    @wrapped.fetch_spec name_tuple
  end

  def uri # :nodoc:
    @wrapped.uri
  end

end

