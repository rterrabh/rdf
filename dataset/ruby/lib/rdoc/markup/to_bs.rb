
class RDoc::Markup::ToBs < RDoc::Markup::ToRdoc


  def initialize markup = nil
    super

    @in_b  = false
    @in_em = false
  end


  def init_tags
    add_tag :BOLD, '+b', '-b'
    add_tag :EM,   '+_', '-_'
    add_tag :TT,   ''  , ''   # we need in_tt information maintained
  end


  def accept_heading heading
    use_prefix or @res << ' ' * @indent
    @res << @headings[heading.level][0]
    @in_b = true
    @res << attributes(heading.text)
    @in_b = false
    @res << @headings[heading.level][1]
    @res << "\n"
  end


  def annotate tag
    case tag
    when '+b' then @in_b = true
    when '-b' then @in_b = false
    when '+_' then @in_em = true
    when '-_' then @in_em = false
    end
    ''
  end


  def convert_special special
    convert_string super
  end


  def convert_string string
    return string unless string.respond_to? :chars # your ruby is lame
    return string unless @in_b or @in_em
    chars = if @in_b then
              string.chars.map do |char| "#{char}\b#{char}" end
            elsif @in_em then
              string.chars.map do |char| "_\b#{char}" end
            end

    chars.join
  end

end

