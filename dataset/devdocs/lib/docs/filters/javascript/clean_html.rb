module Docs
  class Javascript
    class CleanHtmlFilter < Filter
      def call
        root_page? ? root : other
        doc
      end

      def root
        css('#Global_Objects + p').remove
        div = at_css '#Global_Objects + div'
        div.css('h3').each { |node| node.name = 'h2' }
        at_css('#Global_Objects').replace(div.children)

        css('h2 > a').each do |node|
          node.before(node.content)
          node.remove
        end
      end

      def other
        css('.inheritsbox', '.overheadIndicator').each do |node|
          node.remove_attribute 'style'
        end

        css('div > .overheadIndicator:first-child:last-child').each do |node|
          node.parent.replace(node)
        end
      end
    end
  end
end
