require 'cgi'


class RDoc::Markup::ToLabel < RDoc::Markup::Formatter

  attr_reader :res # :nodoc:


  def initialize markup = nil
    super nil, markup

    @markup.add_special RDoc::CrossReference::CROSSREF_REGEXP, :CROSSREF
    @markup.add_special(/(((\{.*?\})|\b\S+?)\[\S+?\])/, :TIDYLINK)

    add_tag :BOLD, '', ''
    add_tag :TT,   '', ''
    add_tag :EM,   '', ''

    @res = []
  end


  def convert text
    label = convert_flow @am.flow text

    CGI.escape(label).gsub('%', '-').sub(/^-/, '')
  end


  def handle_special_CROSSREF special
    text = special.text

    text.sub(/^\\/, '')
  end


  def handle_special_TIDYLINK special
    text = special.text

    return text unless text =~ /\{(.*?)\}\[(.*?)\]/ or text =~ /(\S+)\[(.*?)\]/

    $1
  end

  alias accept_blank_line         ignore
  alias accept_block_quote        ignore
  alias accept_heading            ignore
  alias accept_list_end           ignore
  alias accept_list_item_end      ignore
  alias accept_list_item_start    ignore
  alias accept_list_start         ignore
  alias accept_paragraph          ignore
  alias accept_raw                ignore
  alias accept_rule               ignore
  alias accept_verbatim           ignore
  alias end_accepting             ignore
  alias handle_special_HARD_BREAK ignore
  alias start_accepting           ignore

end

