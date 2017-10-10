require 'html/pipeline/filter'
require 'uri'

module Gitlab
  module Markdown
    class AutolinkFilter < HTML::Pipeline::Filter
      include ActionView::Helpers::TagHelper

      LINK_PATTERN = %r{([a-z][a-z0-9\+\.-]+://\S+)(?<!,|\.)}

      IGNORE_PARENTS = %w(a code kbd pre script style).to_set

      def call
        return doc if context[:autolink] == false

        rinku_parse
        text_parse
      end

      private

      def rinku_parse
        options = tag_options(link_options)

        rinku = Rinku.auto_link(html, :urls, options, IGNORE_PARENTS.to_a, 1)

        @doc = parse_html(rinku)
      end

      def text_parse
        search_text_nodes(doc).each do |node|
          content = node.to_html

          next if has_ancestor?(node, IGNORE_PARENTS)
          next unless content.match(LINK_PATTERN)

          next if content.start_with?(*%w(http https ftp))

          html = autolink_filter(content)

          next if html == content

          node.replace(html)
        end

        doc
      end

      def autolink_filter(text)
        text.gsub(LINK_PATTERN) do |match|
          options = link_options.merge(href: match)
          content_tag(:a, match, options)
        end
      end

      def link_options
        @link_options ||= context[:link_attr] || {}
      end
    end
  end
end
