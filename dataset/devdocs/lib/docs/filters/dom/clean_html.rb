module Docs
  class Dom
    class CleanHtmlFilter < Filter
      def call
        root_page? ? root : other
        doc
      end

      def root
      end

      def other
        css('#offsetContainer .comment').remove

        if (div = at_css('div[style]')) && div['style'].include?('border: solid #ddd 2px')
          div.remove
        end

        if slug.start_with? 'SVG'
          at_css('h2:first-child').try :remove
        end

        css('div > .overheadIndicator:first-child:last-child').each do |node|
          node.parent.replace(node)
        end
      end
    end
  end
end
