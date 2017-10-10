
class RDoc::Markup::List


  attr_accessor :type


  attr_reader :items


  def initialize type = nil, *items
    @type = type
    @items = []
    @items.concat items
  end


  def << item
    @items << item
  end

  def == other # :nodoc:
    self.class == other.class and
      @type == other.type and
      @items == other.items
  end


  def accept visitor
    visitor.accept_list_start self

    @items.each do |item|
      item.accept visitor
    end

    visitor.accept_list_end self
  end


  def empty?
    @items.empty?
  end


  def last
    @items.last
  end

  def pretty_print q # :nodoc:
    q.group 2, "[list: #{@type} ", ']' do
      q.seplist @items do |item|
        q.pp item
      end
    end
  end


  def push *items
    @items.concat items
  end

end

