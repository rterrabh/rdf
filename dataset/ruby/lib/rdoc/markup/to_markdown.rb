

class RDoc::Markup::ToMarkdown < RDoc::Markup::ToRdoc


  def initialize markup = nil
    super

    @headings[1] = ['# ',      '']
    @headings[2] = ['## ',     '']
    @headings[3] = ['### ',    '']
    @headings[4] = ['#### ',   '']
    @headings[5] = ['##### ',  '']
    @headings[6] = ['###### ', '']

    add_special_RDOCLINK
    add_special_TIDYLINK

    @hard_break = "  \n"
  end


  def init_tags
    add_tag :BOLD, '**', '**'
    add_tag :EM,   '*',  '*'
    add_tag :TT,   '`',  '`'
  end


  def handle_special_HARD_BREAK special
    "  \n"
  end


  def accept_list_end list
    @res << "\n"

    super
  end


  def accept_list_item_end list_item
    width = case @list_type.last
            when :BULLET then
              4
            when :NOTE, :LABEL then
              use_prefix

              4
            else
              @list_index[-1] = @list_index.last.succ
              4
            end

    @indent -= width
  end


  def accept_list_item_start list_item
    type = @list_type.last

    case type
    when :NOTE, :LABEL then
      bullets = Array(list_item.label).map do |label|
        attributes(label).strip
      end.join "\n"

      bullets << "\n:"

      @prefix = ' ' * @indent
      @indent += 4
      @prefix << bullets + (' ' * (@indent - 1))
    else
      bullet = type == :BULLET ? '*' : @list_index.last.to_s + '.'
      @prefix = (' ' * @indent) + bullet.ljust(4)

      @indent += 4
    end
  end


  def accept_list_start list
    case list.type
    when :BULLET, :LABEL, :NOTE then
      @list_index << nil
    when :LALPHA, :NUMBER, :UALPHA then
      @list_index << 1
    else
      raise RDoc::Error, "invalid list type #{list.type}"
    end

    @list_width << 4
    @list_type << list.type
  end


  def accept_rule rule
    use_prefix or @res << ' ' * @indent
    @res << '-' * 3
    @res << "\n"
  end


  def accept_verbatim verbatim
    indent = ' ' * (@indent + 4)

    verbatim.parts.each do |part|
      @res << indent unless part == "\n"
      @res << part
    end

    @res << "\n" unless @res =~ /\n\z/
  end


  def gen_url url, text
    scheme, url, = parse_url url

    "[#{text.sub(%r{^#{scheme}:/*}i, '')}](#{url})"
  end


  def handle_rdoc_link url
    case url
    when /^rdoc-ref:/ then
      $'
    when /^rdoc-label:footmark-(\d+)/ then
      "[^#{$1}]:"
    when /^rdoc-label:foottext-(\d+)/ then
      "[^#{$1}]"
    when /^rdoc-label:label-/ then
      gen_url url, $'
    when /^rdoc-image:/ then
      "![](#{$'})"
    when /^rdoc-[a-z]+:/ then
      $'
    end
  end


  def handle_special_TIDYLINK special
    text = special.text

    return text unless text =~ /\{(.*?)\}\[(.*?)\]/ or text =~ /(\S+)\[(.*?)\]/

    label = $1
    url   = $2

    if url =~ /^rdoc-label:foot/ then
      handle_rdoc_link url
    else
      gen_url url, label
    end
  end


  def handle_special_RDOCLINK special
    handle_rdoc_link special.text
  end

end

