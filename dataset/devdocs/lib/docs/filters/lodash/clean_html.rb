module Docs
  class Lodash
    class CleanHtmlFilter < Filter
      def call
        @doc = at_css('h1+div+div')

        css('h3 + p', 'hr').remove

        css('h3').each do |node|
          node['id'] = node.at_css('a')['id']
        end

        css('h2', 'h3').each do |node|
          node.content = node.content
        end

        css('pre').each do |node|
          node.inner_html = node.inner_html.gsub('<br>', "\n").gsub('&nbsp;', ' ')
          node.content = node.content
        end

        doc
      end
    end
  end
end
