
class RDoc::Markup::Raw


  attr_reader :parts


  def initialize *parts
    @parts = []
    @parts.concat parts
  end


  def << text
    @parts << text
  end

  def == other # :nodoc:
    self.class == other.class and @parts == other.parts
  end


  def accept visitor
    visitor.accept_raw self
  end


  def merge other
    @parts.concat other.parts
  end

  def pretty_print q # :nodoc:
    self.class.name =~ /.*::(\w{1,4})/i

    q.group 2, "[#{$1.downcase}: ", ']' do
      q.seplist @parts do |part|
        q.pp part
      end
    end
  end


  def push *texts
    self.parts.concat texts
  end


  def text
    @parts.join ' '
  end

end

