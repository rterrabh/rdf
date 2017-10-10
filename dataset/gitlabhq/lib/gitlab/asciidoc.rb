require 'asciidoctor'
require 'html/pipeline'

module Gitlab
  module Asciidoc

    autoload :RelativeLinkFilter, 'gitlab/markdown/relative_link_filter'

    DEFAULT_ADOC_ATTRS = [
      'showtitle', 'idprefix=user-content-', 'idseparator=-', 'env=gitlab',
      'env-gitlab', 'source-highlighter=html-pipeline'
    ].freeze

    def self.render(input, context, asciidoc_opts = {}, html_opts = {})
      asciidoc_opts = asciidoc_opts.reverse_merge(
        safe: :secure,
        backend: html_opts[:xhtml] ? :xhtml5 : :html5,
        attributes: []
      )
      asciidoc_opts[:attributes].unshift(*DEFAULT_ADOC_ATTRS)

      html = ::Asciidoctor.convert(input, asciidoc_opts)

      if context[:project]
        result = HTML::Pipeline.new(filters).call(html, context)

        save_opts = html_opts[:xhtml] ?
          Nokogiri::XML::Node::SaveOptions::AS_XHTML : 0

        html = result[:output].to_html(save_with: save_opts)
      end

      html.html_safe
    end

    private

    def self.filters
      [
        Gitlab::Markdown::RelativeLinkFilter
      ]
    end
  end
end
