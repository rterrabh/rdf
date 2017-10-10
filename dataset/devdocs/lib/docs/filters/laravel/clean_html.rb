module Docs
  class Laravel
    class CleanHtmlFilter < Filter
      def call
        if subpath.start_with?('/api')
          api
        else
          other
        end

        doc
      end

      def api
        @doc = doc.at_css('#page-content')

        css('.location').remove

        css('.page-header > h1').each do |node|
          node.content = 'Laravel' if root_page?
          node.parent.before(node).remove
        end

        css('.container-fluid').each do |node|
          node.name = 'table'
          node.css('.row').each { |n| n.name = 'tr' }
          node.css('div[class^="col"]').each { |n| n.name = 'td' }
        end

        css('> div').each do |node|
          node.before(node.children).remove
        end

        css('a > abbr').each do |node|
          node.parent['title'] = node['title']
          node.before(node.children).remove
        end

        css('h1 > a', '.content', 'h3 > code', 'h3 strong', 'abbr').each do |node|
          node.before(node.children).remove
        end

        css('td').each do |node|
          node.remove if node.content =~ /\A\s+\z/
        end
      end

      def other
        @doc = at_css('article')

        css('h2 > a').each do |node|
          node.before(node.children).remove
        end

        css('pre').each do |node|
          node.content = node.content
        end
      end
    end
  end
end
