module Docs
  class Sass
    class CleanHtmlFilter < Filter
      def call
        css('tt').each do |node|
          node.name = 'code'
        end

        root_page? ? root : other

        doc
      end

      def root
        at_css('.maruku_toc').remove
      end

      def other
        at_css('h2').remove

        css('.showSource', '.source_code').remove

        css('div.docstring', 'div.discussion').each do |node|
          node.before(node.children).remove
        end

        css('.see').each do |node|
          node.previous_element.remove
          node.remove
        end

        css('.signature', 'span.overload', 'span.signature').each do |node|
          next if node.at_css('.overload')
          node.child.remove while node.child.name != 'strong'
        end

        css('div.inline').each do |node|
          node.content = node.content
          node.name = 'span'
        end

        css('.type > code').each do |node|
          node.before(node.content.remove('Sass::Script::Value::').remove('Sass::Script::')).remove
        end
      end
    end
  end
end
