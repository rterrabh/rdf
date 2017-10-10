module SimpleForm
  module Wrappers
    class Root < Many
      attr_reader :options

      def initialize(*args)
        super(:wrapper, *args)
        @options = @defaults.except(:tag, :class, :error_class, :hint_class)
      end

      def render(input)
        input.options.reverse_merge!(@options)
        super
      end

      def find(name)
        super || SimpleForm::Wrappers::Many.new(name, [Leaf.new(name)])
      end

      private

      def html_classes(input, options)
        css = options[:wrapper_class] ? Array(options[:wrapper_class]) : @defaults[:class]
        css += SimpleForm.additional_classes_for(:wrapper) do
          input.additional_classes + [input.input_class]
        end
        css << (options[:wrapper_error_class] || @defaults[:error_class]) if input.has_errors?
        css << (options[:wrapper_hint_class] || @defaults[:hint_class]) if input.has_hint?
        css.compact
      end
    end
  end
end
