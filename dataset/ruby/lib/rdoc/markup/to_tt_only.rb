
class RDoc::Markup::ToTtOnly < RDoc::Markup::Formatter


  attr_reader :list_type


  attr_reader :res


  def initialize markup = nil
    super nil, markup

    add_tag :TT, nil, nil
  end


  def accept_block_quote block_quote
    tt_sections block_quote.text
  end


  def accept_list_end list
    @list_type.pop
  end


  def accept_list_start list
    @list_type << list.type
  end


  def accept_list_item_start list_item
    case @list_type.last
    when :NOTE, :LABEL then
      Array(list_item.label).map do |label|
        tt_sections label
      end.flatten
    end
  end


  def accept_paragraph paragraph
    tt_sections(paragraph.text)
  end


  def do_nothing markup_item
  end

  alias accept_blank_line    do_nothing # :nodoc:
  alias accept_heading       do_nothing # :nodoc:
  alias accept_list_item_end do_nothing # :nodoc:
  alias accept_raw           do_nothing # :nodoc:
  alias accept_rule          do_nothing # :nodoc:
  alias accept_verbatim      do_nothing # :nodoc:


  def tt_sections text
    flow = @am.flow text.dup

    flow.each do |item|
      case item
      when String then
        @res << item if in_tt?
      when RDoc::Markup::AttrChanger then
        off_tags res, item
        on_tags res, item
      when RDoc::Markup::Special then
        @res << convert_special(item) if in_tt? # TODO can this happen?
      else
        raise "Unknown flow element: #{item.inspect}"
      end
    end

    res
  end


  def end_accepting
    @res.compact
  end


  def start_accepting
    @res = []

    @list_type = []
  end

end

