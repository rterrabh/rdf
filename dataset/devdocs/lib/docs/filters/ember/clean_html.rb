module Docs
  class Ember
    class CleanHtmlFilter < Filter
      def call
        root_page? ? root : other
        doc
      end

      def root
        css('#back-to-top').remove

        css('.level-1:nth-child(1)', '.level-1:nth-child(2)').remove

        css('.level-1 > a').each do |node|
          node.name = 'h2'
          node.remove_attribute 'href'
        end

        css('.level-1').each do |node|
          node.before(node.elements).remove
        end

        css('ol').each do |node|
          node.name = 'ul'
        end
      end

      def other
        css(*%w(hr .edit-page #api-options .toc-anchor .inherited .protected .private .deprecated)).remove

        css('.tabs').each do |node|
          panes = node.css '#methods', '#events', '#properties'
          panes.remove_attr 'style'
          node.before(panes).remove
        end

        css('.method', '.property', '.event').remove_attr('id')

        css('h3[data-id]').each do |node|
          node.name = 'h2'
          node['id'] = node['data-id']
          node.remove_attribute 'data-id'
          node.content = node.content

          div = Nokogiri::XML::Node.new 'div', doc
          div['class'] = 'title'
          node.before(div).parent = div
          div.add_child(div.next_element) while div.next_element.name == 'span'
        end

        css('.highlight').each do |node|
          node.content = node.at_css('.code pre').content
          node.name = 'pre'
        end
      end
    end
  end
end
