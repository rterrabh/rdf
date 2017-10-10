require 'cgi'
require 'erb'
require 'action_view/helpers/form_helper'
require 'active_support/core_ext/string/output_safety'
require 'active_support/core_ext/array/extract_options'
require 'active_support/core_ext/array/wrap'

module ActionView
  module Helpers
    module FormOptionsHelper
      include TextHelper

      def select(object, method, choices = nil, options = {}, html_options = {}, &block)
        Tags::Select.new(object, method, self, choices, options, html_options, &block).render
      end

      def collection_select(object, method, collection, value_method, text_method, options = {}, html_options = {})
        Tags::CollectionSelect.new(object, method, self, collection, value_method, text_method, options, html_options).render
      end

      def grouped_collection_select(object, method, collection, group_method, group_label_method, option_key_method, option_value_method, options = {}, html_options = {})
        Tags::GroupedCollectionSelect.new(object, method, self, collection, group_method, group_label_method, option_key_method, option_value_method, options, html_options).render
      end

      def time_zone_select(object, method, priority_zones = nil, options = {}, html_options = {})
        Tags::TimeZoneSelect.new(object, method, self, priority_zones, options, html_options).render
      end

      def options_for_select(container, selected = nil)
        return container if String === container

        selected, disabled = extract_selected_and_disabled(selected).map do |r|
          Array(r).map { |item| item.to_s }
        end

        container.map do |element|
          html_attributes = option_html_attributes(element)
          text, value = option_text_and_value(element).map { |item| item.to_s }

          html_attributes[:selected] ||= option_value_selected?(value, selected)
          html_attributes[:disabled] ||= disabled && option_value_selected?(value, disabled)
          html_attributes[:value] = value

          content_tag_string(:option, text, html_attributes)
        end.join("\n").html_safe
      end

      def options_from_collection_for_select(collection, value_method, text_method, selected = nil)
        options = collection.map do |element|
          [value_for_collection(element, text_method), value_for_collection(element, value_method), option_html_attributes(element)]
        end
        selected, disabled = extract_selected_and_disabled(selected)
        select_deselect = {
          selected: extract_values_from_collection(collection, value_method, selected),
          disabled: extract_values_from_collection(collection, value_method, disabled)
        }

        options_for_select(options, select_deselect)
      end

      def option_groups_from_collection_for_select(collection, group_method, group_label_method, option_key_method, option_value_method, selected_key = nil)
        collection.map do |group|
          option_tags = options_from_collection_for_select(
            #nodyna <send-1217> <SD COMPLEX (change-prone variables)>
            group.send(group_method), option_key_method, option_value_method, selected_key)

          #nodyna <send-1218> <SD COMPLEX (change-prone variables)>
          content_tag(:optgroup, option_tags, label: group.send(group_label_method))
        end.join.html_safe
      end

      def grouped_options_for_select(grouped_options, selected_key = nil, options = {})
        prompt  = options[:prompt]
        divider = options[:divider]

        body = "".html_safe

        if prompt
          body.safe_concat content_tag(:option, prompt_text(prompt), value: "")
        end

        grouped_options.each do |container|
          html_attributes = option_html_attributes(container)

          if divider
            label = divider
          else
            label, container = container
          end

          html_attributes = { label: label }.merge!(html_attributes)
          body.safe_concat content_tag(:optgroup, options_for_select(container, selected_key), html_attributes)
        end

        body
      end

      def time_zone_options_for_select(selected = nil, priority_zones = nil, model = ::ActiveSupport::TimeZone)
        zone_options = "".html_safe

        zones = model.all
        convert_zones = lambda { |list| list.map { |z| [ z.to_s, z.name ] } }

        if priority_zones
          if priority_zones.is_a?(Regexp)
            priority_zones = zones.select { |z| z =~ priority_zones }
          end

          zone_options.safe_concat options_for_select(convert_zones[priority_zones], selected)
          zone_options.safe_concat content_tag(:option, '-------------', value: '', disabled: true)
          zone_options.safe_concat "\n"

          zones = zones - priority_zones
        end

        zone_options.safe_concat options_for_select(convert_zones[zones], selected)
      end

      def collection_radio_buttons(object, method, collection, value_method, text_method, options = {}, html_options = {}, &block)
        Tags::CollectionRadioButtons.new(object, method, self, collection, value_method, text_method, options, html_options).render(&block)
      end

      def collection_check_boxes(object, method, collection, value_method, text_method, options = {}, html_options = {}, &block)
        Tags::CollectionCheckBoxes.new(object, method, self, collection, value_method, text_method, options, html_options).render(&block)
      end

      private
        def option_html_attributes(element)
          if Array === element
            element.select { |e| Hash === e }.reduce({}, :merge!)
          else
            {}
          end
        end

        def option_text_and_value(option)
          if !option.is_a?(String) && option.respond_to?(:first) && option.respond_to?(:last)
            option = option.reject { |e| Hash === e } if Array === option
            [option.first, option.last]
          else
            [option, option]
          end
        end

        def option_value_selected?(value, selected)
          Array(selected).include? value
        end

        def extract_selected_and_disabled(selected)
          if selected.is_a?(Proc)
            [selected, nil]
          else
            selected = Array.wrap(selected)
            options = selected.extract_options!.symbolize_keys
            selected_items = options.fetch(:selected, selected)
            [selected_items, options[:disabled]]
          end
        end

        def extract_values_from_collection(collection, value_method, selected)
          if selected.is_a?(Proc)
            collection.map do |element|
              #nodyna <send-1219> <SD COMPLEX (change-prone variables)>
              element.send(value_method) if selected.call(element)
            end.compact
          else
            selected
          end
        end

        def value_for_collection(item, value)
          #nodyna <send-1220> <SD COMPLEX (change-prone variables)>
          value.respond_to?(:call) ? value.call(item) : item.send(value)
        end

        def prompt_text(prompt)
          prompt.kind_of?(String) ? prompt : I18n.translate('helpers.select.prompt', default: 'Please select')
        end
    end

    class FormBuilder
      def select(method, choices = nil, options = {}, html_options = {}, &block)
        @template.select(@object_name, method, choices, objectify_options(options), @default_options.merge(html_options), &block)
      end

      def collection_select(method, collection, value_method, text_method, options = {}, html_options = {})
        @template.collection_select(@object_name, method, collection, value_method, text_method, objectify_options(options), @default_options.merge(html_options))
      end

      def grouped_collection_select(method, collection, group_method, group_label_method, option_key_method, option_value_method, options = {}, html_options = {})
        @template.grouped_collection_select(@object_name, method, collection, group_method, group_label_method, option_key_method, option_value_method, objectify_options(options), @default_options.merge(html_options))
      end

      def time_zone_select(method, priority_zones = nil, options = {}, html_options = {})
        @template.time_zone_select(@object_name, method, priority_zones, objectify_options(options), @default_options.merge(html_options))
      end

      def collection_check_boxes(method, collection, value_method, text_method, options = {}, html_options = {}, &block)
        @template.collection_check_boxes(@object_name, method, collection, value_method, text_method, objectify_options(options), @default_options.merge(html_options), &block)
      end

      def collection_radio_buttons(method, collection, value_method, text_method, options = {}, html_options = {}, &block)
        @template.collection_radio_buttons(@object_name, method, collection, value_method, text_method, objectify_options(options), @default_options.merge(html_options), &block)
      end
    end
  end
end
