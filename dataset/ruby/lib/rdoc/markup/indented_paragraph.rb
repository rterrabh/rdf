
class RDoc::Markup::IndentedParagraph < RDoc::Markup::Raw


  attr_reader :indent


  def initialize indent, *parts
    @indent = indent

    super(*parts)
  end

  def == other # :nodoc:
    super and indent == other.indent
  end


  def accept visitor
    visitor.accept_indented_paragraph self
  end


  def text hard_break = nil
    @parts.map do |part|
      if RDoc::Markup::HardBreak === part then
        '%1$s%3$*2$s' % [hard_break, @indent, ' '] if hard_break
      else
        part
      end
    end.join
  end

end

