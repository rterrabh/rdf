module Docs
  class Backbone
    class CleanHtmlFilter < Filter
      def call
        while doc.child['id'] != 'Events'
          doc.child.remove
        end

        while doc.children.last['id'] != 'faq'
          doc.children.last.remove
        end

        css('#faq', '.run').remove

        css('tt').each do |node|
          node.name = 'code'
        end

        doc
      end
    end
  end
end
