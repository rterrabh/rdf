
class RDoc::RD::Inline


  attr_reader :reference


  attr_reader :rdoc


  def self.new rdoc, reference = rdoc
    if self === rdoc and reference.equal? rdoc then
      rdoc
    else
      super
    end
  end


  def initialize rdoc, reference # :not-new:
    @reference = reference.equal?(rdoc) ? reference.dup : reference

    @reference = @reference.reference if self.class === @reference
    @rdoc      = rdoc
  end

  def == other # :nodoc:
    self.class === other and
      @reference == other.reference and @rdoc == other.rdoc
  end


  def append more
    case more
    when String then
      @reference << more
      @rdoc      << more
    when RDoc::RD::Inline then
      @reference << more.reference
      @rdoc      << more.rdoc
    else
      raise "unknown thingy #{more}"
    end

    self
  end

  def inspect # :nodoc:
    "(inline: #{self})"
  end

  alias to_s rdoc # :nodoc:

end

