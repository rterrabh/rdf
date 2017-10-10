require 'simple_form/i18n_cache'
require 'active_support/core_ext/string/output_safety'
require 'action_view/helpers'

module SimpleForm
  module Inputs
    class Base
      include ERB::Util
      include ActionView::Helpers::TranslationHelper

      extend I18nCache

      include SimpleForm::Helpers::Autofocus
      include SimpleForm::Helpers::Disabled
      include SimpleForm::Helpers::Readonly
      include SimpleForm::Helpers::Required
      include SimpleForm::Helpers::Validators

      include SimpleForm::Components::Errors
      include SimpleForm::Components::Hints
      include SimpleForm::Components::HTML5
      include SimpleForm::Components::LabelInput
      include SimpleForm::Components::Maxlength
      include SimpleForm::Components::MinMax
      include SimpleForm::Components::Pattern
      include SimpleForm::Components::Placeholders
      include SimpleForm::Components::Readonly

      attr_reader :attribute_name, :column, :input_type, :reflection,
                  :options, :input_html_options, :input_html_classes, :html_classes

      delegate :template, :object, :object_name, :lookup_model_names, :lookup_action, to: :@builder

      class_attribute :default_options
      self.default_options = {}

      def self.enable(*keys)
        options = self.default_options.dup
        keys.each { |key| options.delete(key) }
        self.default_options = options
      end

      def self.disable(*keys)
        options = self.default_options.dup
        keys.each { |key| options[key] = false }
        self.default_options = options
      end

      enable :hint

      disable :maxlength, :placeholder, :pattern, :min_max

      def initialize(builder, attribute_name, column, input_type, options = {})
        super

        options         = options.dup
        @builder        = builder
        @attribute_name = attribute_name
        @column         = column
        @input_type     = input_type
        @reflection     = options.delete(:reflection)
        @options        = options.reverse_merge!(self.class.default_options)
        @required       = calculate_required

        @html_classes = SimpleForm.additional_classes_for(:input) { additional_classes }

        @input_html_classes = @html_classes.dup
        if SimpleForm.input_class && !input_html_classes.empty?
          input_html_classes << SimpleForm.input_class
        end

        @input_html_options = html_options_for(:input, input_html_classes).tap do |o|
          o[:readonly]  = true if has_readonly?
          o[:disabled]  = true if has_disabled?
          o[:autofocus] = true if has_autofocus?
        end
      end

      def input(wrapper_options = nil)
        raise NotImplementedError
      end

      def input_options
        options
      end

      def additional_classes
        @additional_classes ||= [input_type, required_class, readonly_class, disabled_class].compact
      end

      def input_class
        "#{lookup_model_names.join("_")}_#{reflection_or_attribute_name}"
      end

      private

      def limit
        if column
          decimal_or_float? ? decimal_limit : column_limit
        end
      end

      def column_limit
        column.limit
      end

      def decimal_limit
        column_limit && (column_limit + 1)
      end

      def decimal_or_float?
        column.number? && column.type != :integer
      end

      def nested_boolean_style?
        options.fetch(:boolean_style, SimpleForm.boolean_style) == :nested
      end

      def reflection_or_attribute_name
        @reflection_or_attribute_name ||= reflection ? reflection.name : attribute_name
      end

      def html_options_for(namespace, css_classes)
        html_options = options[:"#{namespace}_html"]
        html_options = html_options ? html_options.dup : {}
        css_classes << html_options[:class] if html_options.key?(:class)
        html_options[:class] = css_classes unless css_classes.empty?
        html_options
      end

      def translate_from_namespace(namespace, default = '')
        model_names = lookup_model_names.dup
        lookups     = []

        while !model_names.empty?
          joined_model_names = model_names.join(".")
          model_names.shift

          lookups << :"#{joined_model_names}.#{lookup_action}.#{reflection_or_attribute_name}"
          lookups << :"#{joined_model_names}.#{lookup_action}.#{reflection_or_attribute_name}_html"
          lookups << :"#{joined_model_names}.#{reflection_or_attribute_name}"
          lookups << :"#{joined_model_names}.#{reflection_or_attribute_name}_html"
        end
        lookups << :"defaults.#{lookup_action}.#{reflection_or_attribute_name}"
        lookups << :"defaults.#{lookup_action}.#{reflection_or_attribute_name}_html"
        lookups << :"defaults.#{reflection_or_attribute_name}"
        lookups << :"defaults.#{reflection_or_attribute_name}_html"
        lookups << default

        t(lookups.shift, scope: :"#{i18n_scope}.#{namespace}", default: lookups).presence
      end

      def merge_wrapper_options(options, wrapper_options)
        if wrapper_options
          options.merge(wrapper_options) do |_, oldval, newval|
            if Array === oldval
              oldval + Array(newval)
            end
          end
        else
          options
        end
      end

      def i18n_scope
        SimpleForm.i18n_scope
      end
    end
  end
end
