
class RDoc::Markup::ToRdoc < RDoc::Markup::Formatter


  attr_accessor :indent


  attr_accessor :width


  attr_reader :list_index


  attr_reader :list_type


  attr_reader :list_width


  attr_reader :prefix


  attr_reader :res


  def initialize markup = nil
    super nil, markup

    @markup.add_special(/\\\S/, :SUPPRESSED_CROSSREF)
    @width = 78
    init_tags

    @headings = {}
    @headings.default = []

    @headings[1] = ['= ',      '']
    @headings[2] = ['== ',     '']
    @headings[3] = ['=== ',    '']
    @headings[4] = ['==== ',   '']
    @headings[5] = ['===== ',  '']
    @headings[6] = ['====== ', '']

    @hard_break = "\n"
  end


  def init_tags
    add_tag :BOLD, "<b>", "</b>"
    add_tag :TT,   "<tt>", "</tt>"
    add_tag :EM,   "<em>", "</em>"
  end


  def accept_blank_line blank_line
    @res << "\n"
  end


  def accept_block_quote block_quote
    @indent += 2

    block_quote.parts.each do |part|
      @prefix = '> '

      part.accept self
    end

    @indent -= 2
  end


  def accept_heading heading
    use_prefix or @res << ' ' * @indent
    @res << @headings[heading.level][0]
    @res << attributes(heading.text)
    @res << @headings[heading.level][1]
    @res << "\n"
  end


  def accept_list_end list
    @list_index.pop
    @list_type.pop
    @list_width.pop
  end


  def accept_list_item_end list_item
    width = case @list_type.last
            when :BULLET then
              2
            when :NOTE, :LABEL then
              if @prefix then
                @res << @prefix.strip
                @prefix = nil
              end

              @res << "\n"
              2
            else
              bullet = @list_index.last.to_s
              @list_index[-1] = @list_index.last.succ
              bullet.length + 2
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

      bullets << ":\n" unless bullets.empty?

      @prefix = ' ' * @indent
      @indent += 2
      @prefix << bullets + (' ' * @indent)
    else
      bullet = type == :BULLET ? '*' :  @list_index.last.to_s + '.'
      @prefix = (' ' * @indent) + bullet.ljust(bullet.length + 1)
      width = bullet.length + 1
      @indent += width
    end
  end


  def accept_list_start list
    case list.type
    when :BULLET then
      @list_index << nil
      @list_width << 1
    when :LABEL, :NOTE then
      @list_index << nil
      @list_width << 2
    when :LALPHA then
      @list_index << 'a'
      @list_width << list.items.length.to_s.length
    when :NUMBER then
      @list_index << 1
      @list_width << list.items.length.to_s.length
    when :UALPHA then
      @list_index << 'A'
      @list_width << list.items.length.to_s.length
    else
      raise RDoc::Error, "invalid list type #{list.type}"
    end

    @list_type << list.type
  end


  def accept_paragraph paragraph
    text = paragraph.text @hard_break
    wrap attributes text
  end


  def accept_indented_paragraph paragraph
    @indent += paragraph.indent
    text = paragraph.text @hard_break
    wrap attributes text
    @indent -= paragraph.indent
  end


  def accept_raw raw
    @res << raw.parts.join("\n")
  end


  def accept_rule rule
    use_prefix or @res << ' ' * @indent
    @res << '-' * (@width - @indent)
    @res << "\n"
  end


  def accept_verbatim verbatim
    indent = ' ' * (@indent + 2)

    verbatim.parts.each do |part|
      @res << indent unless part == "\n"
      @res << part
    end

    @res << "\n" unless @res =~ /\n\z/
  end


  def attributes text
    flow = @am.flow text.dup
    convert_flow flow
  end


  def end_accepting
    @res.join
  end


  def handle_special_SUPPRESSED_CROSSREF special
    text = special.text
    text = text.sub('\\', '') unless in_tt?
    text
  end


  def handle_special_HARD_BREAK special
    "\n"
  end


  def start_accepting
    @res = [""]
    @indent = 0
    @prefix = nil

    @list_index = []
    @list_type  = []
    @list_width = []
  end


  def use_prefix
    prefix, @prefix = @prefix, nil
    @res << prefix if prefix

    prefix
  end


  def wrap text
    return unless text && !text.empty?

    text_len = @width - @indent

    text_len = 20 if text_len < 20

    re = /^(.{0,#{text_len}})[ \n]/
    next_prefix = ' ' * @indent

    prefix = @prefix || next_prefix
    @prefix = nil

    @res << prefix

    while text.length > text_len
      if text =~ re then
        @res << $1
        text.slice!(0, $&.length)
      else
        @res << text.slice!(0, text_len)
      end

      @res << "\n" << next_prefix
    end

    if text.empty? then
      @res.pop
      @res.pop
    else
      @res << text
      @res << "\n"
    end
  end

end

