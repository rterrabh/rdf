
class RDoc::Markup::Special


  attr_reader   :type


  attr_accessor :text


  def initialize(type, text)
    @type, @text = type, text
  end


  def ==(o)
    self.text == o.text && self.type == o.type
  end

  def inspect # :nodoc:
    "#<RDoc::Markup::Special:0x%x @type=%p, @text=%p>" % [
      object_id, @type, text.dump]
  end

  def to_s # :nodoc:
    "Special: type=#{type} text=#{text.dump}"
  end

end

