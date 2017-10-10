

class RDoc::TomDoc < RDoc::Markup::Parser


  attr_reader :tokens


  def self.add_post_processor # :nodoc:
    RDoc::Markup::PreProcess.post_process do |comment, code_object|
      next unless code_object and
                  RDoc::Comment === comment and comment.format == 'tomdoc'

      comment.text.gsub!(/(\A\s*# )(Public|Internal|Deprecated):\s+/) do
        section = code_object.add_section $2
        code_object.temporary_section = section

        $1
      end
    end
  end

  add_post_processor


  def self.parse text
    parser = new

    parser.tokenize text
    doc = RDoc::Markup::Document.new
    parser.parse doc
    doc
  end


  def self.signature comment
    return unless comment.tomdoc?

    document = comment.parse

    signature = nil
    found_heading = false
    found_signature = false

    document.parts.delete_if do |part|
      next false if found_signature

      found_heading ||=
        RDoc::Markup::Heading === part && part.text == 'Signature'

      next false unless found_heading

      next true if RDoc::Markup::BlankLine === part

      if RDoc::Markup::Verbatim === part then
        signature = part
        found_signature = true
      end
    end

    signature and signature.text
  end


  def initialize
    super

    @section      = nil
    @seen_returns = false
  end


  def build_heading level
    heading = super

    @section = heading.text

    heading
  end


  def build_verbatim margin
    verbatim = super

    verbatim.format = :ruby if @section == 'Examples'

    verbatim
  end


  def build_paragraph margin
    p :paragraph_start => margin if @debug

    paragraph = RDoc::Markup::Paragraph.new

    until @tokens.empty? do
      type, data, = get

      case type
      when :TEXT then
        @section = 'Returns' if data =~ /\AReturns/

        paragraph << data
      when :NEWLINE then
        if :TEXT == peek_token[0] then
          paragraph << ' '
        else
          break
        end
      else
        unget
        break
      end
    end

    p :paragraph_end => margin if @debug

    paragraph
  end


  def parse_text parent, indent # :nodoc:
    paragraph = build_paragraph indent

    if false == @seen_returns and 'Returns' == @section then
      @seen_returns = true
      parent << RDoc::Markup::Heading.new(3, 'Returns')
      parent << RDoc::Markup::BlankLine.new
    end

    parent << paragraph
  end


  def tokenize text
    text.sub!(/\A(Public|Internal|Deprecated):\s+/, '')

    setup_scanner text

    until @s.eos? do
      pos = @s.pos

      next if @s.scan(/ +/)

      @tokens << case
                 when @s.scan(/\r?\n/) then
                   token = [:NEWLINE, @s.matched, *token_pos(pos)]
                   @line_pos = char_pos @s.pos
                   @line += 1
                   token
                 when @s.scan(/(Examples|Signature)$/) then
                   @tokens << [:HEADER, 3, *token_pos(pos)]

                   [:TEXT, @s[1], *token_pos(pos)]
                 when @s.scan(/([:\w][\w\[\]]*)[ ]+- /) then
                   [:NOTE, @s[1], *token_pos(pos)]
                 else
                   @s.scan(/.*/)
                   [:TEXT, @s.matched.sub(/\r$/, ''), *token_pos(pos)]
                 end
    end

    self
  end

end

