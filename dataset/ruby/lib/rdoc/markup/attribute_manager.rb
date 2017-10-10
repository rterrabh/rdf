
class RDoc::Markup::AttributeManager


  NULL = "\000".freeze


  A_PROTECT = 004 # :nodoc:


  PROTECT_ATTR = A_PROTECT.chr # :nodoc:


  attr_reader :attributes


  attr_reader :matching_word_pairs


  attr_reader :word_pair_map


  attr_reader :html_tags


  attr_reader :protectable


  attr_reader :special


  def initialize
    @html_tags = {}
    @matching_word_pairs = {}
    @protectable = %w[<]
    @special = []
    @word_pair_map = {}
    @attributes = RDoc::Markup::Attributes.new

    add_word_pair "*", "*", :BOLD
    add_word_pair "_", "_", :EM
    add_word_pair "+", "+", :TT

    add_html "em", :EM
    add_html "i",  :EM
    add_html "b",  :BOLD
    add_html "tt",   :TT
    add_html "code", :TT
  end


  def attribute(turn_on, turn_off)
    RDoc::Markup::AttrChanger.new turn_on, turn_off
  end


  def change_attribute current, new
    diff = current ^ new
    attribute(new & diff, current & diff)
  end


  def changed_attribute_by_name current_set, new_set
    current = new = 0
    current_set.each do |name|
      current |= @attributes.bitmap_for(name)
    end

    new_set.each do |name|
      new |= @attributes.bitmap_for(name)
    end

    change_attribute(current, new)
  end


  def copy_string(start_pos, end_pos)
    res = @str[start_pos...end_pos]
    res.gsub!(/\000/, '')
    res
  end


  def convert_attrs(str, attrs)
    tags = @matching_word_pairs.keys.join("")

    re = /(^|\W)([#{tags}])([#\\]?[\w:.\/-]+?\S?)\2(\W|$)/

    1 while str.gsub!(re) do
      attr = @matching_word_pairs[$2]
      attrs.set_attrs($`.length + $1.length + $2.length, $3.length, attr)
      $1 + NULL * $2.length + $3 + NULL * $2.length + $4
    end

    unless @word_pair_map.empty? then
      @word_pair_map.each do |regexp, attr|
        str.gsub!(regexp) {
          attrs.set_attrs($`.length + $1.length, $2.length, attr)
          NULL * $1.length + $2 + NULL * $3.length
        }
      end
    end
  end


  def convert_html(str, attrs)
    tags = @html_tags.keys.join '|'

    1 while str.gsub!(/<(#{tags})>(.*?)<\/\1>/i) {
      attr = @html_tags[$1.downcase]
      html_length = $1.length + 2
      seq = NULL * html_length
      attrs.set_attrs($`.length + html_length, $2.length, attr)
      seq + $2 + seq + NULL
    }
  end


  def convert_specials str, attrs
    @special.each do |regexp, attribute|
      str.scan(regexp) do
        capture = $~.size == 1 ? 0 : 1

        s, e = $~.offset capture

        attrs.set_attrs s, e - s, attribute | @attributes.special
      end
    end
  end


  def mask_protected_sequences
    @str.gsub!(/__([a-z]+)__/i,
      "_#{PROTECT_ATTR}_#{PROTECT_ATTR}\\1_#{PROTECT_ATTR}_#{PROTECT_ATTR}")
    @str.gsub!(/(\A|[^\\])\\([#{Regexp.escape @protectable.join}])/m,
               "\\1\\2#{PROTECT_ATTR}")
    @str.gsub!(/\\(\\[#{Regexp.escape @protectable.join}])/m, "\\1")
  end


  def unmask_protected_sequences
    @str.gsub!(/(.)#{PROTECT_ATTR}/, "\\1\000")
  end


  def add_word_pair(start, stop, name)
    raise ArgumentError, "Word flags may not start with '<'" if
      start[0,1] == '<'

    bitmap = @attributes.bitmap_for name

    if start == stop then
      @matching_word_pairs[start] = bitmap
    else
      pattern = /(#{Regexp.escape start})(\S+)(#{Regexp.escape stop})/
      @word_pair_map[pattern] = bitmap
    end

    @protectable << start[0,1]
    @protectable.uniq!
  end


  def add_html(tag, name)
    @html_tags[tag.downcase] = @attributes.bitmap_for name
  end


  def add_special pattern, name
    @special << [pattern, @attributes.bitmap_for(name)]
  end


  def flow str
    @str = str

    mask_protected_sequences

    @attrs = RDoc::Markup::AttrSpan.new @str.length

    convert_attrs    @str, @attrs
    convert_html     @str, @attrs
    convert_specials @str, @attrs

    unmask_protected_sequences

    split_into_flow
  end


  def display_attributes
    puts
    puts @str.tr(NULL, "!")
    bit = 1
    16.times do |bno|
      line = ""
      @str.length.times do |i|
        if (@attrs[i] & bit) == 0
          line << " "
        else
          if bno.zero?
            line << "S"
          else
            line << ("%d" % (bno+1))
          end
        end
      end
      puts(line) unless line =~ /^ *$/
      bit <<= 1
    end
  end


  def split_into_flow
    res = []
    current_attr = 0

    str_len = @str.length

    i = 0
    i += 1 while i < str_len and @str[i].chr == "\0"
    start_pos = i

    while i < str_len
      new_attr = @attrs[i]
      if new_attr != current_attr
        if i > start_pos
          res << copy_string(start_pos, i)
          start_pos = i
        end

        res << change_attribute(current_attr, new_attr)
        current_attr = new_attr

        if (current_attr & @attributes.special) != 0 then
          i += 1 while
            i < str_len and (@attrs[i] & @attributes.special) != 0

          res << RDoc::Markup::Special.new(current_attr,
                                           copy_string(start_pos, i))
          start_pos = i
          next
        end
      end

      begin
        i += 1
      end while i < str_len and @str[i].chr == "\0"
    end

    if start_pos < str_len
      res << copy_string(start_pos, str_len)
    end

    res << change_attribute(current_attr, 0) if current_attr != 0

    res
  end

end

