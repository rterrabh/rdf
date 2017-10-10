class RDoc::Markup

  AttrChanger = Struct.new :turn_on, :turn_off # :nodoc:

end


class RDoc::Markup::AttrChanger

  def to_s # :nodoc:
    "Attr: +#{turn_on}/-#{turn_off}"
  end

  def inspect # :nodoc:
    '+%d/-%d' % [turn_on, turn_off]
  end

end

