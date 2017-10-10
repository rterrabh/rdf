
class RDoc::Parser::RD < RDoc::Parser

  include RDoc::Parser::Text

  parse_files_matching(/\.rd(?:\.[^.]+)?$/)


  def scan
    comment = RDoc::Comment.new @content, @top_level
    comment.format = 'rd'

    @top_level.comment = comment
  end

end

