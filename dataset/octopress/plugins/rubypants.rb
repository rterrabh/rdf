


class RubyPants < String

  def initialize(string, options=[2])
    super string
    @options = [*options]
  end

  def to_html
    do_quotes = do_backticks = do_dashes = do_ellipses = do_stupify = nil
    convert_quotes = false

    if @options.include? 0
      return self
    elsif @options.include? 1
      do_quotes = do_backticks = do_ellipses = true
      do_dashes = :normal
    elsif @options.include? 2
      do_quotes = do_backticks = do_ellipses = true
      do_dashes = :oldschool
    elsif @options.include? 3
      do_quotes = do_backticks = do_ellipses = true
      do_dashes = :inverted
    elsif @options.include?(-1)
      do_stupefy = true
    else
      do_quotes =                @options.include? :quotes
      do_backticks =             @options.include? :backticks
      do_backticks = :both    if @options.include? :allbackticks
      do_dashes = :normal     if @options.include? :dashes
      do_dashes = :oldschool  if @options.include? :oldschool
      do_dashes = :inverted   if @options.include? :inverted
      do_ellipses =              @options.include? :ellipses
      convert_quotes =           @options.include? :convertquotes
      do_stupefy =               @options.include? :stupefy
    end

    tokens = tokenize

    in_pre = false

    result = ""

    prev_token_last_char = nil

    tokens.each { |token|
      if token.first == :tag
        result << token[1]
        if token[1] =~ %r!<(/?)(?:pre|code|kbd|script|math)[\s>]!
          in_pre = ($1 != "/")  # Opening or closing tag?
        end
      else
        t = token[1]

        last_char = t[-1].chr

        unless in_pre
          t = process_escapes t

          t.gsub!(/&quot;/, '"')  if convert_quotes

          if do_dashes
            t = educate_dashes t            if do_dashes == :normal
            t = educate_dashes_oldschool t  if do_dashes == :oldschool
            t = educate_dashes_inverted t   if do_dashes == :inverted
          end

          t = educate_ellipses t  if do_ellipses

          if do_backticks
            t = educate_backticks t
            t = educate_single_backticks t  if do_backticks == :both
          end

          if do_quotes
            if t == "'"
              if prev_token_last_char =~ /\S/
                t = "&#8217;"
              else
                t = "&#8216;"
              end
            elsif t == '"'
              if prev_token_last_char =~ /\S/
                t = "&#8221;"
              else
                t = "&#8220;"
              end
            else
              t = educate_quotes t
            end
          end

          t = stupefy_entities t  if do_stupefy
        end

        prev_token_last_char = last_char
        result << t
      end
    }

    result
  end

  protected

  def process_escapes(str)
    str.gsub('\\\\', '&#92;').
      gsub('\"', '&#34;').
      gsub("\\\'", '&#39;').
      gsub('\.', '&#46;').
      gsub('\-', '&#45;').
      gsub('\`', '&#96;')
  end

  def educate_dashes(str)
    str.gsub(/--/, '&#8212;')
  end

  def educate_dashes_oldschool(str)
    str.gsub(/---/, '&#8212;').gsub(/--/, '&#8211;')
  end

  def educate_dashes_inverted(str)
    str.gsub(/---/, '&#8211;').gsub(/--/, '&#8212;')
  end

  def educate_ellipses(str)
    str.gsub('...', '&#8230;').gsub('. . .', '&#8230;')
  end

  def educate_backticks(str)
    str.gsub("``", '&#8220;').gsub("''", '&#8221;')
  end

  def educate_single_backticks(str)
    str.gsub("`", '&#8216;').gsub("'", '&#8217;')
  end

  def educate_quotes(str)
    punct_class = '[!"#\$\%\'()*+,\-.\/:;<=>?\@\[\\\\\]\^_`{|}~]'

    str = str.dup

    str.gsub!(/^'(?=#{punct_class}\B)/, '&#8217;')
    str.gsub!(/^"(?=#{punct_class}\B)/, '&#8221;')

    str.gsub!(/"'(?=\w)/, '&#8220;&#8216;')
    str.gsub!(/'"(?=\w)/, '&#8216;&#8220;')

    str.gsub!(/'(?=\d\ds)/, '&#8217;')

    close_class = %![^\ \t\r\n\\[\{\(\-]!
    dec_dashes = '&#8211;|&#8212;'

    str.gsub!(/(\s|&nbsp;|--|&[mn]dash;|#{dec_dashes}|&#x201[34];)'(?=\w)/,
             '\1&#8216;')
    str.gsub!(/(#{close_class})'/, '\1&#8217;')
    str.gsub!(/'(\s|s\b|$)/, '&#8217;\1')
    str.gsub!(/'/, '&#8216;')

    str.gsub!(/(\s|&nbsp;|--|&[mn]dash;|#{dec_dashes}|&#x201[34];)"(?=\w)/,
             '\1&#8220;')
    str.gsub!(/(#{close_class})"/, '\1&#8221;')
    str.gsub!(/"(\s|s\b|$)/, '&#8221;\1')
    str.gsub!(/"/, '&#8220;')

    str
  end

  def stupefy_entities(str)
    str.
      gsub(/&#8211;/, '-').      # en-dash
      gsub(/&#8212;/, '--').     # em-dash

      gsub(/&#8216;/, "'").      # open single quote
      gsub(/&#8217;/, "'").      # close single quote

      gsub(/&#8220;/, '"').      # open double quote
      gsub(/&#8221;/, '"').      # close double quote

      gsub(/&#8230;/, '...')     # ellipsis
  end

  def tokenize
    tag_soup = /([^<]*)(<[^>]*>)/

    tokens = []

    prev_end = 0
    scan(tag_soup) {
      tokens << [:text, $1]  if $1 != ""
      tokens << [:tag, $2]

      prev_end = $~.end(0)
    }

    if prev_end < size
      tokens << [:text, self[prev_end..-1]]
    end

    tokens
  end
end
