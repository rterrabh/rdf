
class RDoc::Markup::BlockQuote < RDoc::Markup::Raw


  def accept visitor
    visitor.accept_block_quote self
  end

end

