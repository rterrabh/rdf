module SimpleForm
  module Inputs
    class BooleanInput < Base
      def input(wrapper_options = nil)
        merged_input_options = merge_wrapper_options(input_html_options, wrapper_options)

        if nested_boolean_style?
          build_hidden_field_for_checkbox +
            template.label_tag(nil, class: SimpleForm.boolean_label_class) {
              build_check_box_without_hidden_field(merged_input_options) +
                inline_label
            }
        else
          build_check_box(unchecked_value, merged_input_options)
        end
      end

      def label_input(wrapper_options = nil)
        if options[:label] == false || inline_label?
          input(wrapper_options)
        elsif nested_boolean_style?
          html_options = label_html_options.dup
          html_options[:class] ||= []
          html_options[:class].push(SimpleForm.boolean_label_class) if SimpleForm.boolean_label_class

          merged_input_options = merge_wrapper_options(input_html_options, wrapper_options)

          build_hidden_field_for_checkbox +
            @builder.label(label_target, html_options) {
              build_check_box_without_hidden_field(merged_input_options) + label_text
            }
        else
          input(wrapper_options) + label(wrapper_options)
        end
      end

      private

      def build_check_box(unchecked_value, options)
        @builder.check_box(attribute_name, input_html_options, checked_value, unchecked_value)
      end

      def build_check_box_without_hidden_field(options)
        build_check_box(nil, options)
      end

      def build_hidden_field_for_checkbox
        options = { value: unchecked_value, id: nil, disabled: input_html_options[:disabled] }
        options[:name] = input_html_options[:name] if input_html_options.has_key?(:name)

        @builder.hidden_field(attribute_name, options)
      end

      def inline_label?
        nested_boolean_style? && options[:inline_label]
      end

      def inline_label
        inline_option = options[:inline_label]

        if inline_option
          label = inline_option == true ? label_text : html_escape(inline_option)
          " #{label}".html_safe
        end
      end

      def required_by_default?
        false
      end

      def checked_value
        options.fetch(:checked_value, '1')
      end

      def unchecked_value
        options.fetch(:unchecked_value, '0')
      end
    end
  end
end
