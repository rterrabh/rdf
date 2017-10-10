module Docs
  class Go
    class CleanHtmlFilter < Filter
      def call
        if root_page?
          at_css('h1').content = 'Go Programming Language'

          css('tr:first-child + tr', 'th:first-child + th', 'td:first-child + td').remove

          css('td + td:empty').each do |node|
            node.previous_element.content = node.previous_element.content
          end
        end

        css('#plusone', '#nav', '.pkgGopher', '#footer', '.collapsed').remove

        css('h2', '.exampleHeading').each do |node|
          node.content = node.content.remove("\u25BE")
          node.name = 'h2'
        end

        css('#short-nav', '#manual-nav').each do |node|
          node.children = node.css('dd').tap { |nodes| nodes.each { |dd| dd.name = 'li' } }
          node.name = 'ul'
        end

        css('pre').each do |node|
          node.content = node.content
        end

        css('.play').each do |node|
          node.children = node.at_css('.code').children
          node.name = 'pre'
        end

        doc
      end
    end
  end
end
