module ActiveAdmin
  module Views
    class BlankSlate < ActiveAdmin::Component
      builder_method :blank_slate

      def default_class_name
        'blank_slate_container'
      end

      def build(content)
        super(span(content.html_safe, class: "blank_slate"))
      end

    end
  end
end
