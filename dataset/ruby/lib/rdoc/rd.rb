
class RDoc::RD


  def self.parse rd
    rd = rd.lines.to_a

    if rd.find { |i| /\S/ === i } and !rd.find{|i| /^=begin\b/ === i } then
      rd.unshift("=begin\n").push("=end\n")
    end

    parser = RDoc::RD::BlockParser.new
    document = parser.parse rd

    document.parts.shift if RDoc::Markup::BlankLine === document.parts.first
    document.parts.pop   if RDoc::Markup::BlankLine === document.parts.last

    document
  end

  autoload :BlockParser,  'rdoc/rd/block_parser'
  autoload :InlineParser, 'rdoc/rd/inline_parser'
  autoload :Inline,       'rdoc/rd/inline'

end

