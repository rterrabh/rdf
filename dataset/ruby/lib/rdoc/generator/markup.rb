
module RDoc::Generator::Markup


  def aref_to(target_path)
    RDoc::Markup::ToHtml.gen_relative_url path, target_path
  end


  def as_href(from_path)
    RDoc::Markup::ToHtml.gen_relative_url from_path, path
  end


  def description
    markup @comment
  end


  def formatter
    return @formatter if defined? @formatter

    options = @store.rdoc.options
    this = RDoc::Context === self ? self : @parent

    @formatter = RDoc::Markup::ToHtmlCrossref.new options, this.path, this
    @formatter.code_object = self
    @formatter
  end


  def cvs_url(url, full_path)
    if /%s/ =~ url then
      sprintf url, full_path
    else
      url + full_path
    end
  end

end

class RDoc::CodeObject

  include RDoc::Generator::Markup

end

class RDoc::MethodAttr

  @add_line_numbers = false

  class << self

    attr_accessor :add_line_numbers
  end


  def add_line_numbers(src)
    return unless src.sub!(/\A(.*)(, line (\d+))/, '\1')
    first = $3.to_i - 1
    last  = first + src.count("\n")
    size = last.to_s.length

    line = first
    src.gsub!(/^/) do
      res = if line == first then
              " " * (size + 1)
            else
              "<span class=\"line-num\">%2$*1$d</span> " % [size, line]
            end

      line += 1
      res
    end
  end


  def markup_code
    return '' unless @token_stream

    src = RDoc::TokenStream.to_html @token_stream

    indent = src.length
    lines = src.lines.to_a
    lines.shift if src =~ /\A.*#\ *File/i # remove '# File' comment
    lines.each do |line|
      if line =~ /^ *(?=\S)/
        n = $&.length
        indent = n if n < indent
        break if n == 0
      end
    end
    src.gsub!(/^#{' ' * indent}/, '') if indent > 0

    add_line_numbers(src) if RDoc::MethodAttr.add_line_numbers

    src
  end

end

class RDoc::ClassModule


  def description
    markup @comment_location
  end

end

class RDoc::Context::Section

  include RDoc::Generator::Markup

end

class RDoc::TopLevel


  def cvs_url
    url = @store.rdoc.options.webcvs

    if /%s/ =~ url then
      url % @relative_name
    else
      url + @relative_name
    end
  end

end

