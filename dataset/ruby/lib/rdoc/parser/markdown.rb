
class RDoc::Parser::Markdown < RDoc::Parser

  include RDoc::Parser::Text

  parse_files_matching(/\.(md|markdown)(?:\.[^.]+)?$/)


  def scan
    comment = RDoc::Comment.new @content, @top_level
    comment.format = 'markdown'

    @top_level.comment = comment
  end

end


