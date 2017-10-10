
class RDoc::Markup::Paragraph < RDoc::Markup::Raw


  def accept visitor
    visitor.accept_paragraph self
  end


  def text hard_break = ''
    @parts.map do |part|
      if RDoc::Markup::HardBreak === part then
        hard_break
      else
        part
      end
    end.join
  end

end

