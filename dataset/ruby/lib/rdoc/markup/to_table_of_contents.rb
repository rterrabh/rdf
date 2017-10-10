
class RDoc::Markup::ToTableOfContents < RDoc::Markup::Formatter

  @to_toc = nil


  def self.to_toc
    @to_toc ||= new
  end


  attr_reader :res


  attr_accessor :omit_headings_below

  def initialize # :nodoc:
    super nil

    @omit_headings_below = nil
  end


  def accept_document document
    @omit_headings_below = document.omit_headings_below

    super
  end


  def accept_heading heading
    @res << heading unless suppressed? heading
  end


  def end_accepting
    @res
  end


  def start_accepting
    @omit_headings_below = nil
    @res = []
  end


  def suppressed? heading
    return false unless @omit_headings_below

    heading.level > @omit_headings_below
  end

  alias accept_block_quote     ignore
  alias accept_raw             ignore
  alias accept_rule            ignore
  alias accept_blank_line      ignore
  alias accept_paragraph       ignore
  alias accept_verbatim        ignore
  alias accept_list_end        ignore
  alias accept_list_item_start ignore
  alias accept_list_item_end   ignore
  alias accept_list_end_bullet ignore
  alias accept_list_start      ignore

end

