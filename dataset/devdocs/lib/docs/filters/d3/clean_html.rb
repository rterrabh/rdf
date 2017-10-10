module Docs
  class D3
    class CleanHtmlFilter < Filter
      def call
        css('h2 > a').each do |node|
          node.parent['id'] = node['name'].remove('user-content-') if node['name']
          node.before(node.children).remove
        end

        css('.markdown-body > blockquote:first-child', '.anchor').remove

        css('.gh-header-title').each do |node|
          node.parent.parent.before(node).remove
          node.content = 'D3.js' if root_page?
        end

        css('#wiki-content').each do |node|
          node.before(node.at_css('.markdown-body').children).remove
        end

        css('p > a:first-child').each do |node|
          next unless node['name'] || node.content == '#'
          parent = node.parent
          parent.name = 'h6'
          parent['id'] = (node['name'] || node['href'].remove(/\A.+#/)).remove('user-content-')
          parent.css('a[name]').remove
          node.remove
        end

        css('a[href]').each do |node|
          node['href'] = node['href'].sub(/#user\-content\-(\w+?)\z/, '#\1').sub(/#wiki\-(\w+?)\z/, '#\1')
        end

        css('.highlight > pre').each do |node|
          node.content = node.content
        end

        doc
      end
    end
  end
end
