module SimpleForm
  module Components
    module Placeholders
      def placeholder(wrapper_options = nil)
        input_html_options[:placeholder] ||= placeholder_text
        nil
      end

      def placeholder_text
        placeholder = options[:placeholder]
        placeholder.is_a?(String) ? placeholder : translate_from_namespace(:placeholders)
      end
    end
  end
end
