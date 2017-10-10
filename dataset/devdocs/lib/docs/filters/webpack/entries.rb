module Docs
  class Webpack
    class EntriesFilter < Docs::EntriesFilter
      def get_name
        entry_link.content
      end

      def get_type
        link_li = entry_link.parent
        type_links_list = link_li.parent
        current_type = type_links_list.parent

        current_type.children.first.content.strip.titleize
      end

      private

      def entry_link
        at_css("a[href='#{self.path}']")
      end
    end
  end
end

