
class RDoc::I18n::Text


  def initialize(raw)
    @raw = raw
  end


  def extract_messages
    parse do |part|
      case part[:type]
      when :empty_line
      when :paragraph
        yield(part)
      end
    end
  end

  def translate(locale)
    translated_text = ''
    parse do |part|
      case part[:type]
      when :paragraph
        translated_text << locale.translate(part[:paragraph])
      when :empty_line
        translated_text << part[:line]
      else
        raise "should not reach here: unexpected type: #{type}"
      end
    end
    translated_text
  end

  private
  def parse(&block)
    paragraph = ''
    paragraph_start_line = 0
    line_no = 0

    each_line(@raw) do |line|
      line_no += 1
      case line
      when /\A\s*\z/
        if paragraph.empty?
          emit_empty_line_event(line, line_no, &block)
        else
          paragraph << line
          emit_paragraph_event(paragraph, paragraph_start_line, line_no,
                               &block)
          paragraph = ''
        end
      else
        paragraph_start_line = line_no if paragraph.empty?
        paragraph << line
      end
    end

    unless paragraph.empty?
      emit_paragraph_event(paragraph, paragraph_start_line, line_no, &block)
    end
  end

  def each_line(raw, &block)
    case raw
    when RDoc::Comment
      raw.text.each_line(&block)
    when Array
      raw.each do |comment, location|
        each_line(comment, &block)
      end
    else
      raw.each_line(&block)
    end
  end

  def emit_empty_line_event(line, line_no)
    part = {
      :type => :empty_line,
      :line => line,
      :line_no => line_no,
    }
    yield(part)
  end

  def emit_paragraph_event(paragraph, paragraph_start_line, line_no, &block)
    paragraph_part = {
      :type => :paragraph,
      :line_no => paragraph_start_line,
    }
    match_data = /(\s*)\z/.match(paragraph)
    if match_data
      paragraph_part[:paragraph] = match_data.pre_match
      yield(paragraph_part)
      emit_empty_line_event(match_data[1], line_no, &block)
    else
      paragraph_part[:paragraph] = paragraph
      yield(paragraph_part)
    end
  end

end
