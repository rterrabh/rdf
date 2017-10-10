
class RDoc::Comment

  include RDoc::Text


  attr_reader :format


  attr_accessor :location


  alias file location # :nodoc:


  attr_reader :text


  attr_writer   :document


  def initialize text = nil, location = nil
    @location = location
    @text     = text

    @document   = nil
    @format     = 'rdoc'
    @normalized = false
  end


  def initialize_copy copy # :nodoc:
    @text = copy.text.dup
  end

  def == other # :nodoc:
    self.class === other and
      other.text == @text and other.location == @location
  end


  def extract_call_seq method
    if @text =~ /^\s*:?call-seq:(.*?(?:\S).*?)^\s*$/m then
      all_start, all_stop = $~.offset(0)
      seq_start, seq_stop = $~.offset(1)

      if $1 =~ /(^\s*\n)+^(\s*\w+)/m then
        leading = $2 # ' *    ARGF' in the example above
        re = %r%
          \A(
             (^\s*\n)+
             (^#{Regexp.escape leading}.*?\n)+
            )+
          ^\s*$
        %xm

        if @text[seq_stop..-1] =~ re then
          all_stop = seq_stop + $~.offset(0).last
          seq_stop = seq_stop + $~.offset(1).last
        end
      end

      seq = @text[seq_start..seq_stop]
      seq.gsub!(/^\s*(\S|\n)/m, '\1')
      @text.slice! all_start...all_stop

      method.call_seq = seq.chomp

    elsif @text.sub!(/^\s*:?call-seq:(.*?)(^\s*$|\z)/m, '') then
      seq = $1
      seq.gsub!(/^\s*/, '')
      method.call_seq = seq
    end

    method
  end


  def empty?
    @text.empty?
  end


  def force_encoding encoding
    @text.force_encoding encoding
  end


  def format= format
    @format = format
    @document = nil
  end

  def inspect # :nodoc:
    location = @location ? @location.relative_name : '(unknown)'

    "#<%s:%x %s %p>" % [self.class, object_id, location, @text]
  end


  def normalize
    return self unless @text
    return self if @normalized # TODO eliminate duplicate normalization

    @text = normalize_comment @text

    @normalized = true

    self
  end


  def normalized? # :nodoc:
    @normalized
  end


  def parse
    return @document if @document

    @document = super @text, @format
    @document.file = @location
    @document
  end


  def remove_private
    empty = ''
    empty.force_encoding @text.encoding if Object.const_defined? :Encoding

    @text = @text.gsub(%r%^\s*([#*]?)--.*?^\s*(\1)\+\+\n?%m, empty)
    @text = @text.sub(%r%^\s*[#*]?--.*%m, '')
  end


  def text= text
    raise RDoc::Error, 'replacing document-only comment is not allowed' if
      @text.nil? and @document

    @document = nil
    @text = text
  end


  def tomdoc?
    @format == 'tomdoc'
  end

end

