module ActiveAdmin
  module Views

    class TabbedNavigation < Component

      attr_reader :menu

      def build(menu, options = {})
        @menu = menu
        super(default_options.merge(options))
        build_menu
      end

      def menu_items
        menu.items(self)
      end

      def tag_name
        'ul'
      end

      private

      def build_menu
        menu_items.each do |item|
          build_menu_item(item)
        end
      end

      def build_menu_item(item)
        li id: item.id do |li|
          li.add_class "current" if item.current? assigns[:current_tab]

          if url = item.url(self)
            text_node link_to item.label(self), url, item.html_options
          else
            span item.label(self), item.html_options
          end

          if children = item.items(self).presence
            li.add_class "has_nested"
            ul do
              children.each{ |child| build_menu_item child }
            end
          end
        end
      end

      def default_options
        { id: "tabs" }
      end
    end
  end
end
