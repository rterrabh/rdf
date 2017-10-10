
class RDoc::Markup::ToHtmlCrossref < RDoc::Markup::ToHtml

  ALL_CROSSREF_REGEXP = RDoc::CrossReference::ALL_CROSSREF_REGEXP
  CLASS_REGEXP_STR    = RDoc::CrossReference::CLASS_REGEXP_STR
  CROSSREF_REGEXP     = RDoc::CrossReference::CROSSREF_REGEXP
  METHOD_REGEXP_STR   = RDoc::CrossReference::METHOD_REGEXP_STR


  attr_accessor :context


  attr_accessor :show_hash


  def initialize(options, from_path, context, markup = nil)
    raise ArgumentError, 'from_path cannot be nil' if from_path.nil?

    super options, markup

    @context       = context
    @from_path     = from_path
    @hyperlink_all = @options.hyperlink_all
    @show_hash     = @options.show_hash

    crossref_re = @hyperlink_all ? ALL_CROSSREF_REGEXP : CROSSREF_REGEXP
    @markup.add_special crossref_re, :CROSSREF

    @cross_reference = RDoc::CrossReference.new @context
  end


  def cross_reference name, text = nil
    lookup = name

    name = name[1..-1] unless @show_hash if name[0, 1] == '#'

    name = "#{CGI.unescape $'} at #{$1}" if name =~ /(.*[^#:])@/

    text = name unless text

    link lookup, text
  end


  def handle_special_CROSSREF(special)
    name = special.text

    return name if name =~ /@[\w-]+\.[\w-]/ # labels that look like emails

    unless @hyperlink_all then
      return name if name =~ /\A[a-z]*\z/
    end

    cross_reference name
  end


  def handle_special_HYPERLINK special
    return cross_reference $' if special.text =~ /\Ardoc-ref:/

    super
  end


  def handle_special_RDOCLINK special
    url = special.text

    case url
    when /\Ardoc-ref:/ then
      cross_reference $'
    else
      super
    end
  end


  def gen_url url, text
    return super unless url =~ /\Ardoc-ref:/

    cross_reference $', text
  end


  def link name, text
    original_name = name

    if name =~ /(.*[^#:])@/ then
      name = $1
      label = $'
    end

    ref = @cross_reference.resolve name, text

    text = ref.output_name @context if
      RDoc::MethodAttr === ref and text == original_name

    case ref
    when String then
      ref
    else
      path = ref.as_href @from_path

      if path =~ /#/ then
        path << "-label-#{label}"
      elsif ref.sections and
            ref.sections.any? { |section| label == section.title } then
        path << "##{label}"
      else
        path << "#label-#{label}"
      end if label

      "<a href=\"#{path}\">#{text}</a>"
    end
  end

end

