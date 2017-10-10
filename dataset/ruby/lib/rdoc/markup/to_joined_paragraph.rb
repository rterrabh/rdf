
class RDoc::Markup::ToJoinedParagraph < RDoc::Markup::Formatter

  def initialize # :nodoc:
    super nil
  end

  def start_accepting # :nodoc:
  end

  def end_accepting # :nodoc:
  end


  def accept_paragraph paragraph
    parts = []
    string = false

    paragraph.parts.each do |part|
      if String === part then
        if string then
          string << part
        else
          parts << part
          string = part
        end
      else
        parts << part
        string = false
      end
    end

    parts = parts.map do |part|
      if String === part then
        part.rstrip
      else
        part
      end
    end


    paragraph.parts.replace parts
  end

  alias accept_block_quote     ignore
  alias accept_heading         ignore
  alias accept_list_end        ignore
  alias accept_list_item_end   ignore
  alias accept_list_item_start ignore
  alias accept_list_start      ignore
  alias accept_raw             ignore
  alias accept_rule            ignore
  alias accept_verbatim        ignore

end

