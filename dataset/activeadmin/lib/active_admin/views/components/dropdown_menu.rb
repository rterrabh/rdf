require 'active_admin/views/components/popover'

module ActiveAdmin
  module Views

    class DropdownMenu < ActiveAdmin::Component
      builder_method :dropdown_menu

      def build(name, options = {})
        options = options.dup

        button_options  = options.delete(:button) || {}
        menu_options = options.delete(:menu) || {}

        @button  = build_button(name, button_options)
        @menu = build_menu(menu_options)

        super(options)
      end

      def item(*args)
        within @menu do
          li link_to(*args)
        end
      end

      private

      def build_button(name, button_options)
        button_options[:class] ||= ''
        button_options[:class] << ' dropdown_menu_button'

        button_options[:href] = '#'

        a name, button_options
      end

      def build_menu(options)
        options[:class] ||= ''
        options[:class] << ' dropdown_menu_list'

        menu_list = nil

        div :class => 'dropdown_menu_list_wrapper' do
          menu_list = ul(options)
        end

        menu_list
      end

    end

  end
end
