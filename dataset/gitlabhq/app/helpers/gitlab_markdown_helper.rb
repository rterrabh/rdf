require 'nokogiri'

module GitlabMarkdownHelper
  include Gitlab::Markdown
  include PreferencesHelper

  def link_to_gfm(body, url, html_options = {})
    return "" if body.blank?

    escaped_body = if body =~ /\A\<img/
                     body
                   else
                     escape_once(body)
                   end

    gfm_body = gfm(escaped_body, {}, html_options)

    fragment = Nokogiri::XML::DocumentFragment.parse(gfm_body)
    if fragment.children.size == 1 && fragment.children[0].name == 'a'
      text = fragment.children[0].text
      fragment.children[0].replace(link_to(text, url, html_options))
    else
      fragment.children.each do |node|
        next unless node.text?
        node.replace(link_to(node.text, url, html_options))
      end
    end

    fragment.to_html.html_safe
  end

  MARKDOWN_OPTIONS = {
    no_intra_emphasis:   true,
    tables:              true,
    fenced_code_blocks:  true,
    strikethrough:       true,
    lax_spacing:         true,
    space_after_headers: true,
    superscript:         true,
    footnotes:           true
  }.freeze

  def markdown(text, options={})
    unless @markdown && options == @options
      @options = options

      rend = Redcarpet::Render::GitlabHTML.new(self, user_color_scheme_class, options)

      @markdown = Redcarpet::Markdown.new(rend, MARKDOWN_OPTIONS)
    end

    @markdown.render(text).html_safe
  end

  def asciidoc(text)
    Gitlab::Asciidoc.render(text, {
      commit: @commit,
      project: @project,
      project_wiki: @project_wiki,
      requested_path: @path,
      ref: @ref
    })
  end

  def first_line_in_markdown(text, max_chars = nil, options = {})
    md = markdown(text, options).strip

    truncate_visible(md, max_chars || md.length) if md.present?
  end

  def render_wiki_content(wiki_page)
    case wiki_page.format
    when :markdown
      markdown(wiki_page.content)
    when :asciidoc
      asciidoc(wiki_page.content)
    else
      wiki_page.formatted_content.html_safe
    end
  end

  MARKDOWN_TIPS = [
    "End a line with two or more spaces for a line-break, or soft-return",
    "Inline code can be denoted by `surrounding it with backticks`",
    "Blocks of code can be denoted by three backticks ``` or four leading spaces",
    "Emoji can be added by :emoji_name:, for example :thumbsup:",
    "Notify other participants using @user_name",
    "Notify a specific group using @group_name",
    "Notify the entire team using @all",
    "Reference an issue using a hash, for example issue #123",
    "Reference a merge request using an exclamation point, for example MR !123",
    "Italicize words or phrases using *asterisks* or _underscores_",
    "Bold words or phrases using **double asterisks** or __double underscores__",
    "Strikethrough words or phrases using ~~two tildes~~",
    "Make a bulleted list using + pluses, - minuses, or * asterisks",
    "Denote blockquotes using > at the beginning of a line",
    "Make a horizontal line using three or more hyphens ---, asterisks ***, or underscores ___"
  ].freeze

  def random_markdown_tip
    MARKDOWN_TIPS.sample
  end

  private

  def truncate_visible(text, max_chars)
    doc = Nokogiri::HTML.fragment(text)
    content_length = 0
    truncated = false

    doc.traverse do |node|
      if node.text? || node.content.empty?
        if truncated
          node.remove
          next
        end

        if node.content.strip.lines.length > 1
          node.content = "#{node.content.lines.first.chomp}..."
          truncated = true
        end

        num_remaining = max_chars - content_length
        if node.content.length > num_remaining
          node.content = node.content.truncate(num_remaining)
          truncated = true
        end
        content_length += node.content.length
      end

      truncated = truncate_if_block(node, truncated)
    end

    doc.to_html
  end

  def truncate_if_block(node, truncated)
    if node.element? && node.description.block? && !truncated
      node.content = "#{node.content}..." if node.next_sibling
      true
    else
      truncated
    end
  end

  def cross_project_reference(project, entity)
    if entity.respond_to?(:to_reference)
      "#{project.to_reference}#{entity.to_reference}"
    else
      ''
    end
  end
end
