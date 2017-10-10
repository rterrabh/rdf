require 'cgi'


class RDoc::Markup::ToHtml < RDoc::Markup::Formatter

  include RDoc::Text



  LIST_TYPE_TO_HTML = {
    :BULLET => ['<ul>',                                      '</ul>'],
    :LABEL  => ['<dl class="rdoc-list label-list">',         '</dl>'],
    :LALPHA => ['<ol style="list-style-type: lower-alpha">', '</ol>'],
    :NOTE   => ['<dl class="rdoc-list note-list">',          '</dl>'],
    :NUMBER => ['<ol>',                                      '</ol>'],
    :UALPHA => ['<ol style="list-style-type: upper-alpha">', '</ol>'],
  }

  attr_reader :res # :nodoc:
  attr_reader :in_list_entry # :nodoc:
  attr_reader :list # :nodoc:


  attr_accessor :code_object


  attr_accessor :from_path



  def initialize options, markup = nil
    super

    @code_object = nil
    @from_path = ''
    @in_list_entry = nil
    @list = nil
    @th = nil
    @hard_break = "<br>\n"

    @markup.add_special(/(?:link:|https?:|mailto:|ftp:|irc:|www\.)\S+\w/,
                        :HYPERLINK)

    add_special_RDOCLINK
    add_special_TIDYLINK

    init_tags
  end


  def handle_RDOCLINK url # :nodoc:
    case url
    when /^rdoc-ref:/
      $'
    when /^rdoc-label:/
      text = $'

      text = case text
             when /\Alabel-/    then $'
             when /\Afootmark-/ then $'
             when /\Afoottext-/ then $'
             else                    text
             end

      gen_url url, text
    when /^rdoc-image:/
      "<img src=\"#{$'}\">"
    else
      url =~ /\Ardoc-[a-z]+:/

      $'
    end
  end


  def handle_special_HARD_BREAK special
    '<br>'
  end


  def handle_special_HYPERLINK(special)
    url = special.text

    gen_url url, url
  end


  def handle_special_RDOCLINK special
    handle_RDOCLINK special.text
  end


  def handle_special_TIDYLINK(special)
    text = special.text

    return text unless
      text =~ /^\{(.*)\}\[(.*?)\]$/ or text =~ /^(\S+)\[(.*?)\]$/

    label = $1
    url   = $2

    label = handle_RDOCLINK label if /^rdoc-image:/ =~ label

    gen_url url, label
  end



  def start_accepting
    @res = []
    @in_list_entry = []
    @list = []
  end


  def end_accepting
    @res.join
  end


  def accept_block_quote block_quote
    @res << "\n<blockquote>"

    block_quote.parts.each do |part|
      part.accept self
    end

    @res << "</blockquote>\n"
  end


  def accept_paragraph paragraph
    @res << "\n<p>"
    text = paragraph.text @hard_break
    text = text.gsub(/\r?\n/, ' ')
    @res << wrap(to_html(text))
    @res << "</p>\n"
  end


  def accept_verbatim verbatim
    text = verbatim.text.rstrip

    klass = nil

    content = if verbatim.ruby? or parseable? text then
                begin
                  tokens = RDoc::RubyLex.tokenize text, @options
                  klass  = ' class="ruby"'

                  RDoc::TokenStream.to_html tokens
                rescue RDoc::RubyLex::Error
                  CGI.escapeHTML text
                end
              else
                CGI.escapeHTML text
              end

    if @options.pipe then
      @res << "\n<pre><code>#{CGI.escapeHTML text}</code></pre>\n"
    else
      @res << "\n<pre#{klass}>#{content}</pre>\n"
    end
  end


  def accept_rule rule
    @res << "<hr>\n"
  end


  def accept_list_start(list)
    @list << list.type
    @res << html_list_name(list.type, true)
    @in_list_entry.push false
  end


  def accept_list_end(list)
    @list.pop
    if tag = @in_list_entry.pop
      @res << tag
    end
    @res << html_list_name(list.type, false) << "\n"
  end


  def accept_list_item_start(list_item)
    if tag = @in_list_entry.last
      @res << tag
    end

    @res << list_item_start(list_item, @list.last)
  end


  def accept_list_item_end(list_item)
    @in_list_entry[-1] = list_end_for(@list.last)
  end


  def accept_blank_line(blank_line)
  end


  def accept_heading heading
    level = [6, heading.level].min

    label = heading.label @code_object

    @res << if @options.output_decoration
              "\n<h#{level} id=\"#{label}\">"
            else
              "\n<h#{level}>"
            end
    @res << to_html(heading.text)
    unless @options.pipe then
      @res << "<span><a href=\"##{label}\">&para;</a>"
      @res << " <a href=\"#top\">&uarr;</a></span>"
    end
    @res << "</h#{level}>\n"
  end


  def accept_raw raw
    @res << raw.parts.join("\n")
  end



  def convert_string(text)
    CGI.escapeHTML text
  end


  def gen_url url, text
    scheme, url, id = parse_url url

    if %w[http https link].include?(scheme) and
       url =~ /\.(gif|png|jpg|jpeg|bmp)$/ then
      "<img src=\"#{url}\" />"
    else
      text = text.sub %r%^#{scheme}:/*%i, ''
      text = text.sub %r%^[*\^](\d+)$%,   '\1'

      link = "<a#{id} href=\"#{url}\">#{text}</a>"

      link = "<sup>#{link}</sup>" if /"foot/ =~ id

      link
    end
  end


  def html_list_name(list_type, open_tag)
    tags = LIST_TYPE_TO_HTML[list_type]
    raise RDoc::Error, "Invalid list type: #{list_type.inspect}" unless tags
    tags[open_tag ? 0 : 1]
  end


  def init_tags
    add_tag :BOLD, "<strong>", "</strong>"
    add_tag :TT,   "<code>",   "</code>"
    add_tag :EM,   "<em>",     "</em>"
  end


  def list_item_start(list_item, list_type)
    case list_type
    when :BULLET, :LALPHA, :NUMBER, :UALPHA then
      "<li>"
    when :LABEL, :NOTE then
      Array(list_item.label).map do |label|
        "<dt>#{to_html label}\n"
      end.join << "<dd>"
    else
      raise RDoc::Error, "Invalid list type: #{list_type.inspect}"
    end
  end


  def list_end_for(list_type)
    case list_type
    when :BULLET, :LALPHA, :NUMBER, :UALPHA then
      "</li>"
    when :LABEL, :NOTE then
      "</dd>"
    else
      raise RDoc::Error, "Invalid list type: #{list_type.inspect}"
    end
  end


  def parseable? text
    #nodyna <eval-2026> <EV COMPLEX (change-prone variables)>
    eval("BEGIN {return true}\n#{text}")
  rescue SyntaxError
    false
  end


  def to_html item
    super convert_flow @am.flow item
  end

end

