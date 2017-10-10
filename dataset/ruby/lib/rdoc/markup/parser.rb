require 'strscan'


class RDoc::Markup::Parser

  include RDoc::Text


  LIST_TOKENS = [
    :BULLET,
    :LABEL,
    :LALPHA,
    :NOTE,
    :NUMBER,
    :UALPHA,
  ]


  class Error < RuntimeError; end


  class ParseError < Error; end


  attr_accessor :debug


  attr_reader :tokens


  def self.parse str
    parser = new
    parser.tokenize str
    doc = RDoc::Markup::Document.new
    parser.parse doc
  end


  def self.tokenize str
    parser = new
    parser.tokenize str
    parser.tokens
  end


  def initialize
    @binary_input   = nil
    @current_token  = nil
    @debug          = false
    @have_encoding  = Object.const_defined? :Encoding
    @have_byteslice = ''.respond_to? :byteslice
    @input          = nil
    @input_encoding = nil
    @line           = 0
    @line_pos       = 0
    @s              = nil
    @tokens         = []
  end


  def build_heading level
    type, text, = get

    text = case type
           when :TEXT then
             skip :NEWLINE
             text
           else
             unget
             ''
           end

    RDoc::Markup::Heading.new level, text
  end


  def build_list margin
    p :list_start => margin if @debug

    list = RDoc::Markup::List.new
    label = nil

    until @tokens.empty? do
      type, data, column, = get

      case type
      when *LIST_TOKENS then
        if column < margin || (list.type && list.type != type) then
          unget
          break
        end

        list.type = type
        peek_type, _, column, = peek_token

        case type
        when :NOTE, :LABEL then
          label = [] unless label

          if peek_type == :NEWLINE then
            while peek_type == :NEWLINE
              get
              peek_type, _, column, = peek_token
            end

            if peek_type.nil? || column < margin then
              empty = true
            elsif column == margin then
              case peek_type
              when type
                empty = :continue
              when *LIST_TOKENS
                empty = true
              else
                empty = false
              end
            else
              empty = false
            end

            if empty then
              label << data
              next if empty == :continue
              break
            end
          end
        else
          data = nil
        end

        if label then
          data = label << data
          label = nil
        end

        list_item = RDoc::Markup::ListItem.new data
        parse list_item, column
        list << list_item

      else
        unget
        break
      end
    end

    p :list_end => margin if @debug

    if list.empty? then
      return nil unless label
      return nil unless [:LABEL, :NOTE].include? list.type

      list_item = RDoc::Markup::ListItem.new label, RDoc::Markup::BlankLine.new
      list << list_item
    end

    list
  end


  def build_paragraph margin
    p :paragraph_start => margin if @debug

    paragraph = RDoc::Markup::Paragraph.new

    until @tokens.empty? do
      type, data, column, = get

      if type == :TEXT and column == margin then
        paragraph << data

        break if peek_token.first == :BREAK

        data << ' ' if skip :NEWLINE
      else
        unget
        break
      end
    end

    paragraph.parts.last.sub!(/ \z/, '') # cleanup

    p :paragraph_end => margin if @debug

    paragraph
  end


  def build_verbatim margin
    p :verbatim_begin => margin if @debug
    verbatim = RDoc::Markup::Verbatim.new

    min_indent = nil
    generate_leading_spaces = true
    line = ''

    until @tokens.empty? do
      type, data, column, = get

      if type == :NEWLINE then
        line << data
        verbatim << line
        line = ''
        generate_leading_spaces = true
        next
      end

      if column <= margin
        unget
        break
      end

      if generate_leading_spaces then
        indent = column - margin
        line << ' ' * indent
        min_indent = indent if min_indent.nil? || indent < min_indent
        generate_leading_spaces = false
      end

      case type
      when :HEADER then
        line << '=' * data
        _, _, peek_column, = peek_token
        peek_column ||= column + data
        indent = peek_column - column - data
        line << ' ' * indent
      when :RULE then
        width = 2 + data
        line << '-' * width
        _, _, peek_column, = peek_token
        peek_column ||= column + width
        indent = peek_column - column - width
        line << ' ' * indent
      when :BREAK, :TEXT then
        line << data
      else # *LIST_TOKENS
        list_marker = case type
                      when :BULLET then data
                      when :LABEL  then "[#{data}]"
                      when :NOTE   then "#{data}::"
                      else # :LALPHA, :NUMBER, :UALPHA
                        "#{data}."
                      end
        line << list_marker
        peek_type, _, peek_column = peek_token
        unless peek_type == :NEWLINE then
          peek_column ||= column + list_marker.length
          indent = peek_column - column - list_marker.length
          line << ' ' * indent
        end
      end

    end

    verbatim << line << "\n" unless line.empty?
    verbatim.parts.each { |p| p.slice!(0, min_indent) unless p == "\n" } if min_indent > 0
    verbatim.normalize

    p :verbatim_end => margin if @debug

    verbatim
  end


  def char_pos byte_offset
    if @have_byteslice then
      @input.byteslice(0, byte_offset).length
    elsif @have_encoding then
      matched = @binary_input[0, byte_offset]
      matched.force_encoding @input_encoding
      matched.length
    else
      byte_offset
    end
  end


  def get
    @current_token = @tokens.shift
    p :get => @current_token if @debug
    @current_token
  end


  def parse parent, indent = 0
    p :parse_start => indent if @debug

    until @tokens.empty? do
      type, data, column, = get

      case type
      when :BREAK then
        parent << RDoc::Markup::BlankLine.new
        skip :NEWLINE, false
        next
      when :NEWLINE then
        parent << RDoc::Markup::BlankLine.new
        skip :NEWLINE, false
        next
      end

      if column < indent then
        unget
        break
      elsif column > indent then
        unget
        parent << build_verbatim(indent)
        next
      end

      case type
      when :HEADER then
        parent << build_heading(data)
      when :RULE then
        parent << RDoc::Markup::Rule.new(data)
        skip :NEWLINE
      when :TEXT then
        unget
        parse_text parent, indent
      when *LIST_TOKENS then
        unget
        parent << build_list(indent)
      else
        type, data, column, line = @current_token
        raise ParseError, "Unhandled token #{type} (#{data.inspect}) at #{line}:#{column}"
      end
    end

    p :parse_end => indent if @debug

    parent

  end


  def parse_text parent, indent # :nodoc:
    parent << build_paragraph(indent)
  end


  def peek_token
    token = @tokens.first || []
    p :peek => token if @debug
    token
  end


  def setup_scanner input
    @line     = 0
    @line_pos = 0
    @input    = input.dup

    if @have_encoding and not @have_byteslice then
      @input_encoding = @input.encoding
      @binary_input   = @input.force_encoding Encoding::BINARY
    end

    @s = StringScanner.new input
  end


  def skip token_type, error = true
    type, = get
    return unless type # end of stream
    return @current_token if token_type == type
    unget
    raise ParseError, "expected #{token_type} got #{@current_token.inspect}" if error
  end


  def tokenize input
    setup_scanner input

    until @s.eos? do
      pos = @s.pos

      next if @s.scan(/ +/)


      @tokens << case
                 when @s.scan(/\r?\n/) then
                   token = [:NEWLINE, @s.matched, *token_pos(pos)]
                   @line_pos = char_pos @s.pos
                   @line += 1
                   token
                 when @s.scan(/(=+)(\s*)/) then
                   level = @s[1].length
                   header = [:HEADER, level, *token_pos(pos)]

                   if @s[2] =~ /^\r?\n/ then
                     @s.pos -= @s[2].length
                     header
                   else
                     pos = @s.pos
                     @s.scan(/.*/)
                     @tokens << header
                     [:TEXT, @s.matched.sub(/\r$/, ''), *token_pos(pos)]
                   end
                 when @s.scan(/(-{3,}) *\r?$/) then
                   [:RULE, @s[1].length - 2, *token_pos(pos)]
                 when @s.scan(/([*-]) +(\S)/) then
                   @s.pos -= @s[2].bytesize # unget \S
                   [:BULLET, @s[1], *token_pos(pos)]
                 when @s.scan(/([a-z]|\d+)\. +(\S)/i) then
                   list_label = @s[1]
                   @s.pos -= @s[2].bytesize # unget \S
                   list_type =
                     case list_label
                     when /[a-z]/ then :LALPHA
                     when /[A-Z]/ then :UALPHA
                     when /\d/    then :NUMBER
                     else
                       raise ParseError, "BUG token #{list_label}"
                     end
                   [list_type, list_label, *token_pos(pos)]
                 when @s.scan(/\[(.*?)\]( +|\r?$)/) then
                   [:LABEL, @s[1], *token_pos(pos)]
                 when @s.scan(/(.*?)::( +|\r?$)/) then
                   [:NOTE, @s[1], *token_pos(pos)]
                 else @s.scan(/(.*?)(  )?\r?$/)
                   token = [:TEXT, @s[1], *token_pos(pos)]

                   if @s[2] then
                     @tokens << token
                     [:BREAK, @s[2], *token_pos(pos + @s[1].length)]
                   else
                     token
                   end
                 end
    end

    self
  end


  def token_pos byte_offset
    offset = char_pos byte_offset

    [offset - @line_pos, @line]
  end


  def unget
    token = @current_token
    p :unget => token if @debug
    raise Error, 'too many #ungets' if token == @tokens.first
    @tokens.unshift token if token
  end

end

