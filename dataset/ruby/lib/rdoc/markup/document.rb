
class RDoc::Markup::Document

  include Enumerable


  attr_reader :file


  attr_accessor :omit_headings_below


  attr_reader :parts


  def initialize *parts
    @parts = []
    @parts.concat parts

    @file = nil
    @omit_headings_from_table_of_contents_below = nil
  end


  def << part
    case part
    when RDoc::Markup::Document then
      unless part.empty? then
        parts.concat part.parts
        parts << RDoc::Markup::BlankLine.new
      end
    when String then
      raise ArgumentError,
            "expected RDoc::Markup::Document and friends, got String" unless
        part.empty?
    else
      parts << part
    end
  end

  def == other # :nodoc:
    self.class == other.class and
      @file == other.file and
      @parts == other.parts
  end


  def accept visitor
    visitor.start_accepting

    visitor.accept_document self

    visitor.end_accepting
  end


  def concat parts
    self.parts.concat parts
  end


  def each &block
    @parts.each(&block)
  end


  def empty?
    @parts.empty? or (@parts.length == 1 and merged? and @parts.first.empty?)
  end


  def file= location
    @file = case location
            when RDoc::TopLevel then
              location.relative_name
            else
              location
            end
  end


  def merge other
    if empty? then
      @parts = other.parts
      return self
    end

    other.parts.each do |other_part|
      self.parts.delete_if do |self_part|
        self_part.file and self_part.file == other_part.file
      end

      self.parts << other_part
    end

    self
  end


  def merged?
    RDoc::Markup::Document === @parts.first
  end

  def pretty_print q # :nodoc:
    start = @file ? "[doc (#{@file}): " : '[doc: '

    q.group 2, start, ']' do
      q.seplist @parts do |part|
        q.pp part
      end
    end
  end


  def push *parts
    self.parts.concat parts
  end


  def table_of_contents
    accept RDoc::Markup::ToTableOfContents.to_toc
  end

end

