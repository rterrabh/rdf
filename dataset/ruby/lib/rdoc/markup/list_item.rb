
class RDoc::Markup::ListItem


  attr_accessor :label


  attr_reader :parts


  def initialize label = nil, *parts
    @label = label
    @parts = []
    @parts.concat parts
  end


  def << part
    @parts << part
  end

  def == other # :nodoc:
    self.class == other.class and
      @label == other.label and
      @parts == other.parts
  end


  def accept visitor
    visitor.accept_list_item_start self

    @parts.each do |part|
      part.accept visitor
    end

    visitor.accept_list_item_end self
  end


  def empty?
    @parts.empty?
  end


  def length
    @parts.length
  end

  def pretty_print q # :nodoc:
    q.group 2, '[item: ', ']' do
      case @label
      when Array then
        q.pp @label
        q.text ';'
        q.breakable
      when String then
        q.pp @label
        q.text ';'
        q.breakable
      end

      q.seplist @parts do |part|
        q.pp part
      end
    end
  end


  def push *parts
    @parts.concat parts
  end

end

