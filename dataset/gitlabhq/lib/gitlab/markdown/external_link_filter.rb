require 'html/pipeline/filter'

module Gitlab
  module Markdown
    class ExternalLinkFilter < HTML::Pipeline::Filter
      def call
        doc.search('a').each do |node|
          next unless node.has_attribute?('href')

          link = node.attribute('href').value

          next unless link.start_with?('http')

          next if link.start_with?(internal_url)

          node.set_attribute('rel', 'nofollow')
        end

        doc
      end

      private

      def internal_url
        @internal_url ||= Gitlab.config.gitlab.url
      end
    end
  end
end
