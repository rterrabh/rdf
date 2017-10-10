module Docs
  class Css
    class CleanHtmlFilter < Filter
      def call
        root_page? ? root : other
        doc
      end

      def root
        css('#CSS3_Tutorials ~ *', '#CSS3_Tutorials').remove
      end

      def other
        css('.syntaxbox', '.twopartsyntaxbox').css('a').each do |node|
          if node.content == '|' || node.content == '||'
            node.replace node.content
          end
        end
      end
    end
  end
end
