module Docs
  class Rdoc
    class ContainerFilter < Filter
      def call
        if root_page?
          at_css 'main'
        else
          container = at_css 'main'

          meta = Nokogiri::XML::Node.new 'dl', doc
          meta['class'] = 'meta'

          if parent = at_css('#parent-class-section')
            meta << %(<dt>Parent:</dt><dd class="meta-parent">#{parent.at_css('.link').inner_html.strip}</dd>)
          end

          if includes = at_css('#includes-section')
            meta << %(<dt>Included modules:</dt><dd class="meta-includes">#{includes.css('a').map(&:to_html).join(', ')}</dd>)
          end

          if parent || includes
            container.at_css('h1').after(meta)
          end

          container
        end
      end
    end
  end
end