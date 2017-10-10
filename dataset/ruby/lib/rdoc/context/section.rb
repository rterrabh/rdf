
class RDoc::Context::Section

  include RDoc::Text

  MARSHAL_VERSION = 0 # :nodoc:


  attr_reader :comment


  attr_reader :comments


  attr_reader :parent


  attr_reader :title

  @@sequence = "SEC00000"


  def initialize parent, title, comment
    @parent = parent
    @title = title ? title.strip : title

    @@sequence.succ!
    @sequence = @@sequence.dup

    @comments = []

    add_comment comment
  end


  def == other
    self.class === other and @title == other.title
  end


  def add_comment comment
    comment = extract_comment comment

    return if comment.empty?

    case comment
    when RDoc::Comment then
      @comments << comment
    when RDoc::Markup::Document then
      @comments.concat comment.parts
    when Array then
      @comments.concat comment
    else
      raise TypeError, "unknown comment type: #{comment.inspect}"
    end
  end


  def aref
    title = @title || '[untitled]'

    CGI.escape(title).gsub('%', '-').sub(/^-/, '')
  end


  def extract_comment comment
    case comment
    when Array then
      comment.map do |c|
        extract_comment c
      end
    when nil
      RDoc::Comment.new ''
    when RDoc::Comment then
      if comment.text =~ /^#[ \t]*:section:.*\n/ then
        start = $`
        rest = $'

        comment.text = if start.empty? then
                         rest
                       else
                         rest.sub(/#{start.chomp}\Z/, '')
                       end
      end

      comment
    when RDoc::Markup::Document then
      comment
    else
      raise TypeError, "unknown comment #{comment.inspect}"
    end
  end

  def inspect # :nodoc:
    "#<%s:0x%x %p>" % [self.class, object_id, title]
  end


  def in_files
    return [] if @comments.empty?

    case @comments
    when Array then
      @comments.map do |comment|
        comment.file
      end
    when RDoc::Markup::Document then
      @comment.parts.map do |document|
        document.file
      end
    else
      raise RDoc::Error, "BUG: unknown comment class #{@comments.class}"
    end
  end


  def marshal_dump
    [
      MARSHAL_VERSION,
      @title,
      parse,
    ]
  end


  def marshal_load array
    @parent  = nil

    @title    = array[1]
    @comments = array[2]
  end


  def parse
    case @comments
    when String then
      super
    when Array then
      docs = @comments.map do |comment, location|
        doc = super comment
        doc.file = location if location
        doc
      end

      RDoc::Markup::Document.new(*docs)
    when RDoc::Comment then
      doc = super @comments.text, comments.format
      doc.file = @comments.location
      doc
    when RDoc::Markup::Document then
      return @comments
    else
      raise ArgumentError, "unknown comment class #{comments.class}"
    end
  end


  def plain_html
    @title || 'Top Section'
  end


  def remove_comment comment
    return if @comments.empty?

    case @comments
    when Array then
      @comments.delete_if do |my_comment|
        my_comment.file == comment.file
      end
    when RDoc::Markup::Document then
      @comments.parts.delete_if do |document|
        document.file == comment.file.name
      end
    else
      raise RDoc::Error, "BUG: unknown comment class #{@comments.class}"
    end
  end


  def sequence
    warn "RDoc::Context::Section#sequence is deprecated, use #aref"
    @sequence
  end

end

