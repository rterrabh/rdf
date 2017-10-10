
class RDoc::Markup


  attr_reader :attribute_manager


  def self.parse str
    RDoc::Markup::Parser.parse str
  rescue RDoc::Markup::Parser::Error => e
    $stderr.puts <<-EOF
While parsing markup, RDoc encountered a #{e.class}:

\tfrom #{e.backtrace.join "\n\tfrom "}

---8<---
---8<---

RDoc #{RDoc::VERSION}

Ruby #{RUBY_VERSION}-p#{RUBY_PATCHLEVEL} #{RUBY_RELEASE_DATE}

Please file a bug report with the above information at:

https://github.com/rdoc/rdoc/issues

    EOF
    raise
  end


  def initialize attribute_manager = nil
    @attribute_manager = attribute_manager || RDoc::Markup::AttributeManager.new
    @output = nil
  end


  def add_word_pair(start, stop, name)
    @attribute_manager.add_word_pair(start, stop, name)
  end


  def add_html(tag, name)
    @attribute_manager.add_html(tag, name)
  end


  def add_special(pattern, name)
    @attribute_manager.add_special(pattern, name)
  end


  def convert input, formatter
    document = case input
               when RDoc::Markup::Document then
                 input
               else
                 RDoc::Markup::Parser.parse input
               end

    document.accept formatter
  end

  autoload :Parser,                'rdoc/markup/parser'
  autoload :PreProcess,            'rdoc/markup/pre_process'

  autoload :AttrChanger,           'rdoc/markup/attr_changer'
  autoload :AttrSpan,              'rdoc/markup/attr_span'
  autoload :Attributes,            'rdoc/markup/attributes'
  autoload :AttributeManager,      'rdoc/markup/attribute_manager'
  autoload :Special,               'rdoc/markup/special'

  autoload :BlankLine,             'rdoc/markup/blank_line'
  autoload :BlockQuote,            'rdoc/markup/block_quote'
  autoload :Document,              'rdoc/markup/document'
  autoload :HardBreak,             'rdoc/markup/hard_break'
  autoload :Heading,               'rdoc/markup/heading'
  autoload :Include,               'rdoc/markup/include'
  autoload :IndentedParagraph,     'rdoc/markup/indented_paragraph'
  autoload :List,                  'rdoc/markup/list'
  autoload :ListItem,              'rdoc/markup/list_item'
  autoload :Paragraph,             'rdoc/markup/paragraph'
  autoload :Raw,                   'rdoc/markup/raw'
  autoload :Rule,                  'rdoc/markup/rule'
  autoload :Verbatim,              'rdoc/markup/verbatim'

  autoload :Formatter,             'rdoc/markup/formatter'
  autoload :FormatterTestCase,     'rdoc/markup/formatter_test_case'
  autoload :TextFormatterTestCase, 'rdoc/markup/text_formatter_test_case'

  autoload :ToAnsi,                'rdoc/markup/to_ansi'
  autoload :ToBs,                  'rdoc/markup/to_bs'
  autoload :ToHtml,                'rdoc/markup/to_html'
  autoload :ToHtmlCrossref,        'rdoc/markup/to_html_crossref'
  autoload :ToHtmlSnippet,         'rdoc/markup/to_html_snippet'
  autoload :ToLabel,               'rdoc/markup/to_label'
  autoload :ToMarkdown,            'rdoc/markup/to_markdown'
  autoload :ToRdoc,                'rdoc/markup/to_rdoc'
  autoload :ToTableOfContents,     'rdoc/markup/to_table_of_contents'
  autoload :ToTest,                'rdoc/markup/to_test'
  autoload :ToTtOnly,              'rdoc/markup/to_tt_only'

end

