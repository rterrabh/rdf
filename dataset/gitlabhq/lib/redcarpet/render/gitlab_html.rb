require 'active_support/core_ext/string/output_safety'

class Redcarpet::Render::GitlabHTML < Redcarpet::Render::HTML
  attr_reader :template
  alias_method :h, :template

  def initialize(template, color_scheme, options = {})
    @template = template
    @color_scheme = color_scheme
    @options = options.dup

    @options.reverse_merge!(
      escape_html: false,
      #nodyna <instance_variable_get-498> <IVG COMPLEX (private access)>
      project: @template.instance_variable_get("@project")
    )

    super(options)
  end

  def normal_text(text)
    ERB::Util.html_escape_once(text)
  end

  def block_code(code, language)
    lexer = Rouge::Lexer.find_fancy(language, code) || Rouge::Lexers::PlainText

    if lexer.tag == 'make'
      code.gsub!(/^    /, "\t")
    end

    formatter = Rouge::Formatters::HTMLGitlab.new(
      cssclass: "code highlight #{@color_scheme} #{lexer.tag}"
    )
    formatter.format(lexer.lex(code))
  end

  def postprocess(full_document)
    h.gfm(full_document, @options)
  end
end
