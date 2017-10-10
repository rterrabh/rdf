require 'active_support/core_ext/string/output_safety'
require 'html/pipeline/filter'

module Gitlab
  module Markdown
    class ReferenceFilter < HTML::Pipeline::Filter
      def initialize(*args)
        super

        result[:references] = Hash.new { |hash, type| hash[type] = [] }
      end

      def data_attribute(id, type = :project)
        %Q(data-#{type}-id="#{id}")
      end

      def escape_once(html)
        ERB::Util.html_escape_once(html)
      end

      def ignore_parents
        @ignore_parents ||= begin
          parents = %w(pre code a style)
          parents << 'blockquote' if context[:ignore_blockquotes]
          parents.to_set
        end
      end

      def ignored_ancestry?(node)
        has_ancestor?(node, ignore_parents)
      end

      def project
        context[:project]
      end

      def push_result(type, *values)
        return if values.empty?

        result[:references][type].push(*values)
      end

      def reference_class(type)
        "gfm gfm-#{type} #{context[:reference_class]}".strip
      end

      def replace_text_nodes_matching(pattern)
        return doc if project.nil?

        search_text_nodes(doc).each do |node|
          content = node.to_html

          next unless content.match(pattern)
          next if ignored_ancestry?(node)

          html = yield content

          next if html == content

          node.replace(html)
        end

        doc
      end

      def validate
        needs :project
      end
    end
  end
end
