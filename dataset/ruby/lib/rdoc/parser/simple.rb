
class RDoc::Parser::Simple < RDoc::Parser

  include RDoc::Parser::Text

  parse_files_matching(//)

  attr_reader :content # :nodoc:


  def initialize(top_level, file_name, content, options, stats)
    super

    preprocess = RDoc::Markup::PreProcess.new @file_name, @options.rdoc_include

    preprocess.handle @content, @top_level
  end


  def scan
    comment = remove_coding_comment @content
    comment = remove_private_comment comment

    comment = RDoc::Comment.new comment, @top_level

    @top_level.comment = comment
    @top_level
  end


  def remove_coding_comment text
    text.sub(/\A# .*coding[=:].*$/, '')
  end


  def remove_private_comment comment
    empty = ''
    empty.force_encoding comment.encoding if Object.const_defined? :Encoding

    comment = comment.gsub(%r%^--\n.*?^\+\+\n?%m, empty)
    comment.sub(%r%^--\n.*%m, empty)
  end

end

