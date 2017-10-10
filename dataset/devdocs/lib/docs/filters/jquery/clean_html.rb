module Docs
  class Jquery
    class CleanHtmlFilter < Filter
      def call
        css('hr', '.icon-link', '.entry-meta').remove

        if css('> article').length == 1
          doc.children = at_css('article').children
        end

        if root_page?
          at_css('.page-title').remove

          css('h1.entry-title').each do |node|
            node.name = 'h2'
          end
        end

        css('.entry-header > .entry-title', 'header > .underline', 'header > h2:only-child').to_a.uniq.each do |node|
          node.parent.replace node
        end

        css('div.syntaxhighlighter').each do |node|
          node.name = 'pre'
          node.content = node.at_css('td.code').css('div.line').map(&:content).join("\n")
        end

        css('dd > dl').each do |node|
          node.parent.replace(node)
        end

        doc
      end
    end
  end
end
