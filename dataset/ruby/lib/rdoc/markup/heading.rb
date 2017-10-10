
RDoc::Markup::Heading =
  Struct.new :level, :text do

  @to_html = nil
  @to_label = nil


  def self.to_label
    @to_label ||= RDoc::Markup::ToLabel.new
  end


  def self.to_html
    return @to_html if @to_html

    markup = RDoc::Markup.new
    markup.add_special RDoc::CrossReference::CROSSREF_REGEXP, :CROSSREF

    @to_html = RDoc::Markup::ToHtml.new nil

    def @to_html.handle_special_CROSSREF special
      special.text.sub(/^\\/, '')
    end

    @to_html
  end


  def accept visitor
    visitor.accept_heading self
  end


  def aref
    "label-#{self.class.to_label.convert text.dup}"
  end


  def label context = nil
    label = aref

    label = [context.aref, label].compact.join '-' if
      context and context.respond_to? :aref

    label
  end


  def plain_html
    self.class.to_html.to_html(text.dup)
  end

  def pretty_print q # :nodoc:
    q.group 2, "[head: #{level} ", ']' do
      q.pp text
    end
  end

end

