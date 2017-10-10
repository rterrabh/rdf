
class RDoc::Markup::HardBreak

  @instance = new


  def self.new
    @instance
  end


  def accept visitor
    visitor.accept_hard_break self
  end

  def == other # :nodoc:
    self.class === other
  end

  def pretty_print q # :nodoc:
    q.text "[break]"
  end

end

