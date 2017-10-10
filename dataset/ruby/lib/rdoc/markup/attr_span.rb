
class RDoc::Markup::AttrSpan


  def initialize(length)
    @attrs = Array.new(length, 0)
  end

  def set_attrs(start, length, bits)
    for i in start ... (start+length)
      @attrs[i] |= bits
    end
  end


  def [](n)
    @attrs[n]
  end

end

