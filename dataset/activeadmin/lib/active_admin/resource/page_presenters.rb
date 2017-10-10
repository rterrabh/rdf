module ActiveAdmin
  class Resource
    module PagePresenters

      def default_index_class
        @default_index
      end

      def page_presenters
        @page_presenters ||= {}
      end

      def set_page_presenter(action, page_presenter)

        if action.to_s == "index" && page_presenter[:as]
          index_class = find_index_class(page_presenter[:as])
          page_presenter_key = index_class.index_name.to_sym
          set_index_presenter page_presenter_key, page_presenter
        else
          page_presenters[action.to_sym] = page_presenter
        end

      end

      def get_page_presenter(action, type=nil)

        if action.to_s == "index" && type && page_presenters[:index].kind_of?(Hash)
          page_presenters[:index][type.to_sym]
        elsif action.to_s == "index" && page_presenters[:index].kind_of?(Hash)
          page_presenters[:index].default
        else
          page_presenters[action.to_sym]
        end

      end

      protected

      def set_index_presenter(index_as, page_presenter)
        page_presenters[:index] ||= {}

        if page_presenters[:index].empty? || page_presenter[:default] == true
          page_presenters[:index].default = page_presenter
          @default_index = find_index_class(page_presenter[:as])
        end

        page_presenters[:index][index_as] = page_presenter
      end

      def find_index_class(symbol_or_class)
        case symbol_or_class
        when Symbol
          #nodyna <const_get-108> <CG COMPLEX (change-prone variable)>
          ::ActiveAdmin::Views.const_get("IndexAs" + symbol_or_class.to_s.camelcase)
        when Class
          symbol_or_class
        end
      end

    end
  end
end
