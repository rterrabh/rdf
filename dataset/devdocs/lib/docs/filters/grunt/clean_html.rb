module Docs
  class Grunt
    class CleanHtmlFilter < Filter
      def call
        @doc = at_css('.hero-unit')

        if root_page?
          at_css('h1').content = 'Grunt'
        end

        css('.end-link').remove

        css('a.anchor').each do |node|
          node.parent['id'] = node['name']
          node.before(node.children).remove
        end

        css('pre').each do |node|
          node.content = node.content
        end

        doc
      end
    end
  end
end
