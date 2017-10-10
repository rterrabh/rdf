module Docs
  class Rdoc
    class CleanHtmlFilter < Filter
      def call
        root_page? ? root : other
        doc
      end

      def root
        css('#methods + ul', 'h1', 'h2', 'li > ul').remove

        css('li > span').each do |node|
          node.parent.remove
        end
      end

      def other
        css('hr').remove

        css('h1 > span', 'h2 > span', 'h3 > span', 'h4 > span', 'h5 > span', 'h6 > span').remove

        css('.method-detail').each do |node|
          next unless heading = node.at_css('.method-heading')
          heading['id'] = node['id']
          node.remove_attribute 'id'
        end

        css('.method-click-advice').each do |node|
          node.name = 'a'
          node.content = 'Show source'
        end

        css('.method-source-code > pre').each do |node|
          node['class'] = node.at_css('.ruby-keyword') ? 'ruby' : 'c'
        end

        css('pre').each do |node|
          node.content = node.content
        end
      end
    end
  end
end
