
class RDoc::Generator::POT::POEntry

  attr_reader :msgid

  attr_reader :msgstr

  attr_reader :translator_comment

  attr_reader :extracted_comment

  attr_reader :references

  attr_reader :flags


  def initialize msgid, options = {}
    @msgid = msgid
    @msgstr = options[:msgstr] || ""
    @translator_comment = options[:translator_comment]
    @extracted_comment = options[:extracted_comment]
    @references = options[:references] || []
    @flags = options[:flags] || []
  end


  def to_s
    entry = ''
    entry << format_translator_comment
    entry << format_extracted_comment
    entry << format_references
    entry << format_flags
    entry << <<-ENTRY
msgid #{format_message(@msgid)}
msgstr #{format_message(@msgstr)}
    ENTRY
  end


  def merge other_entry
    options = {
      :extracted_comment  => merge_string(@extracted_comment,
                                          other_entry.extracted_comment),
      :translator_comment => merge_string(@translator_comment,
                                          other_entry.translator_comment),
      :references         => merge_array(@references,
                                         other_entry.references),
      :flags              => merge_array(@flags,
                                         other_entry.flags),
    }
    self.class.new(@msgid, options)
  end

  private

  def format_comment mark, comment
    return '' unless comment
    return '' if comment.empty?

    formatted_comment = ''
    comment.each_line do |line|
      formatted_comment << "#{mark} #{line}"
    end
    formatted_comment << "\n" unless formatted_comment.end_with?("\n")
    formatted_comment
  end

  def format_translator_comment
    format_comment('#', @translator_comment)
  end

  def format_extracted_comment
    format_comment('#.', @extracted_comment)
  end

  def format_references
    return '' if @references.empty?

    formatted_references = ''
    @references.sort.each do |file, line|
      formatted_references << "\#: #{file}:#{line}\n"
    end
    formatted_references
  end

  def format_flags
    return '' if @flags.empty?

    formatted_flags = flags.join(",")
    "\#, #{formatted_flags}\n"
  end

  def format_message message
    return "\"#{escape(message)}\"" unless message.include?("\n")

    formatted_message = '""'
    message.each_line do |line|
      formatted_message << "\n"
      formatted_message << "\"#{escape(line)}\""
    end
    formatted_message
  end

  def escape string
    string.gsub(/["\\\t\n]/) do |special_character|
      case special_character
      when "\t"
        "\\t"
      when "\n"
        "\\n"
      else
        "\\#{special_character}"
      end
    end
  end

  def merge_string string1, string2
    [string1, string2].compact.join("\n")
  end

  def merge_array array1, array2
      (array1 + array2).uniq
  end

end
