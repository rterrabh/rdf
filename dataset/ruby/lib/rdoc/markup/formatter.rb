
class RDoc::Markup::Formatter


  InlineTag = Struct.new(:bit, :on, :off)


  def self.gen_relative_url path, target
    from        = File.dirname path
    to, to_file = File.split target

    from = from.split "/"
    to   = to.split "/"

    from.delete '.'
    to.delete '.'

    while from.size > 0 and to.size > 0 and from[0] == to[0] do
      from.shift
      to.shift
    end

    from.fill ".."
    from.concat to
    from << to_file
    File.join(*from)
  end


  def initialize options, markup = nil
    @options = options

    @markup = markup || RDoc::Markup.new
    @am     = @markup.attribute_manager
    @am.add_special(/<br>/, :HARD_BREAK)

    @attributes = @am.attributes

    @attr_tags = []

    @in_tt = 0
    @tt_bit = @attributes.bitmap_for :TT

    @hard_break = ''
    @from_path = '.'
  end


  def accept_document document
    document.parts.each do |item|
      case item
      when RDoc::Markup::Document then # HACK
        accept_document item
      else
        item.accept self
      end
    end
  end


  def add_special_RDOCLINK
    @markup.add_special(/rdoc-[a-z]+:[^\s\]]+/, :RDOCLINK)
  end


  def add_special_TIDYLINK
    @markup.add_special(/(?:
                          \{.*?\} |    # multi-word label
                          \b[^\s{}]+? # single-word label
                         )

                         \[\S+?\]     # link target
                        /x, :TIDYLINK)
  end


  def add_tag(name, start, stop)
    attr = @attributes.bitmap_for name
    @attr_tags << InlineTag.new(attr, start, stop)
  end


  def annotate(tag)
    tag
  end


  def convert content
    @markup.convert content, self
  end


  def convert_flow(flow)
    res = []

    flow.each do |item|
      case item
      when String then
        res << convert_string(item)
      when RDoc::Markup::AttrChanger then
        off_tags res, item
        on_tags res, item
      when RDoc::Markup::Special then
        res << convert_special(item)
      else
        raise "Unknown flow element: #{item.inspect}"
      end
    end

    res.join
  end


  def convert_special special
    return special.text if in_tt?

    handled = false

    @attributes.each_name_of special.type do |name|
      method_name = "handle_special_#{name}"

      if respond_to? method_name then
        #nodyna <send-2029> <SD COMPLEX (change-prone variables)>
        special.text = send method_name, special
        handled = true
      end
    end

    unless handled then
      special_name = @attributes.as_string special.type

      raise RDoc::Error, "Unhandled special #{special_name}: #{special}"
    end

    special.text
  end


  def convert_string string
    string
  end


  def ignore *node
  end


  def in_tt?
    @in_tt > 0
  end


  def on_tags res, item
    attr_mask = item.turn_on
    return if attr_mask.zero?

    @attr_tags.each do |tag|
      if attr_mask & tag.bit != 0 then
        res << annotate(tag.on)
        @in_tt += 1 if tt? tag
      end
    end
  end


  def off_tags res, item
    attr_mask = item.turn_off
    return if attr_mask.zero?

    @attr_tags.reverse_each do |tag|
      if attr_mask & tag.bit != 0 then
        @in_tt -= 1 if tt? tag
        res << annotate(tag.off)
      end
    end
  end


  def parse_url url
    case url
    when /^rdoc-label:([^:]*)(?::(.*))?/ then
      scheme = 'link'
      path   = "##{$1}"
      id     = " id=\"#{$2}\"" if $2
    when /([A-Za-z]+):(.*)/ then
      scheme = $1.downcase
      path   = $2
    when /^#/ then
    else
      scheme = 'http'
      path   = url
      url    = url
    end

    if scheme == 'link' then
      url = if path[0, 1] == '#' then # is this meaningful?
              path
            else
              self.class.gen_relative_url @from_path, path
            end
    end

    [scheme, url, id]
  end


  def tt? tag
    tag.bit == @tt_bit
  end

end

