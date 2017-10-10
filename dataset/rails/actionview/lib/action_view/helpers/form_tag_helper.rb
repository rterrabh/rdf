require 'cgi'
require 'action_view/helpers/tag_helper'
require 'active_support/core_ext/string/output_safety'
require 'active_support/core_ext/module/attribute_accessors'

module ActionView
  module Helpers
    module FormTagHelper
      extend ActiveSupport::Concern

      include UrlHelper
      include TextHelper

      mattr_accessor :embed_authenticity_token_in_remote_forms
      self.embed_authenticity_token_in_remote_forms = false

      def form_tag(url_for_options = {}, options = {}, &block)
        html_options = html_options_for_form(url_for_options, options)
        if block_given?
          form_tag_with_body(html_options, capture(&block))
        else
          form_tag_html(html_options)
        end
      end

      def select_tag(name, option_tags = nil, options = {})
        option_tags ||= ""
        html_name = (options[:multiple] == true && !name.to_s.ends_with?("[]")) ? "#{name}[]" : name

        if options.include?(:include_blank)
          include_blank = options.delete(:include_blank)

          if include_blank == true
            include_blank = ''
          end

          if include_blank
            option_tags = content_tag(:option, include_blank, value: '').safe_concat(option_tags)
          end
        end

        if prompt = options.delete(:prompt)
          option_tags = content_tag(:option, prompt, value: '').safe_concat(option_tags)
        end

        content_tag :select, option_tags, { "name" => html_name, "id" => sanitize_to_id(name) }.update(options.stringify_keys)
      end

      def text_field_tag(name, value = nil, options = {})
        tag :input, { "type" => "text", "name" => name, "id" => sanitize_to_id(name), "value" => value }.update(options.stringify_keys)
      end

      def label_tag(name = nil, content_or_options = nil, options = nil, &block)
        if block_given? && content_or_options.is_a?(Hash)
          options = content_or_options = content_or_options.stringify_keys
        else
          options ||= {}
          options = options.stringify_keys
        end
        options["for"] = sanitize_to_id(name) unless name.blank? || options.has_key?("for")
        content_tag :label, content_or_options || name.to_s.humanize, options, &block
      end

      def hidden_field_tag(name, value = nil, options = {})
        text_field_tag(name, value, options.merge(type: :hidden))
      end

      def file_field_tag(name, options = {})
        text_field_tag(name, nil, options.merge(type: :file))
      end

      def password_field_tag(name = "password", value = nil, options = {})
        text_field_tag(name, value, options.merge(type: :password))
      end

      def text_area_tag(name, content = nil, options = {})
        options = options.stringify_keys

        if size = options.delete("size")
          options["cols"], options["rows"] = size.split("x") if size.respond_to?(:split)
        end

        escape = options.delete("escape") { true }
        content = ERB::Util.html_escape(content) if escape

        content_tag :textarea, content.to_s.html_safe, { "name" => name, "id" => sanitize_to_id(name) }.update(options)
      end

      def check_box_tag(name, value = "1", checked = false, options = {})
        html_options = { "type" => "checkbox", "name" => name, "id" => sanitize_to_id(name), "value" => value }.update(options.stringify_keys)
        html_options["checked"] = "checked" if checked
        tag :input, html_options
      end

      def radio_button_tag(name, value, checked = false, options = {})
        html_options = { "type" => "radio", "name" => name, "id" => "#{sanitize_to_id(name)}_#{sanitize_to_id(value)}", "value" => value }.update(options.stringify_keys)
        html_options["checked"] = "checked" if checked
        tag :input, html_options
      end

      def submit_tag(value = "Save changes", options = {})
        options = options.stringify_keys

        tag :input, { "type" => "submit", "name" => "commit", "value" => value }.update(options)
      end

      def button_tag(content_or_options = nil, options = nil, &block)
        if content_or_options.is_a? Hash
          options = content_or_options
        else
          options ||= {}
        end

        options = { 'name' => 'button', 'type' => 'submit' }.merge!(options.stringify_keys)

        if block_given?
          content_tag :button, options, &block
        else
          content_tag :button, content_or_options || 'Button', options
        end
      end

      def image_submit_tag(source, options = {})
        options = options.stringify_keys
        tag :input, { "alt" => image_alt(source), "type" => "image", "src" => path_to_image(source) }.update(options)
      end

      def field_set_tag(legend = nil, options = nil, &block)
        output = tag(:fieldset, options, true)
        output.safe_concat(content_tag(:legend, legend)) unless legend.blank?
        output.concat(capture(&block)) if block_given?
        output.safe_concat("</fieldset>")
      end

      def color_field_tag(name, value = nil, options = {})
        text_field_tag(name, value, options.merge(type: :color))
      end

      def search_field_tag(name, value = nil, options = {})
        text_field_tag(name, value, options.merge(type: :search))
      end

      def telephone_field_tag(name, value = nil, options = {})
        text_field_tag(name, value, options.merge(type: :tel))
      end
      alias phone_field_tag telephone_field_tag

      def date_field_tag(name, value = nil, options = {})
        text_field_tag(name, value, options.merge(type: :date))
      end

      def time_field_tag(name, value = nil, options = {})
        text_field_tag(name, value, options.merge(type: :time))
      end

      def datetime_field_tag(name, value = nil, options = {})
        text_field_tag(name, value, options.merge(type: :datetime))
      end

      def datetime_local_field_tag(name, value = nil, options = {})
        text_field_tag(name, value, options.merge(type: 'datetime-local'))
      end

      def month_field_tag(name, value = nil, options = {})
        text_field_tag(name, value, options.merge(type: :month))
      end

      def week_field_tag(name, value = nil, options = {})
        text_field_tag(name, value, options.merge(type: :week))
      end

      def url_field_tag(name, value = nil, options = {})
        text_field_tag(name, value, options.merge(type: :url))
      end

      def email_field_tag(name, value = nil, options = {})
        text_field_tag(name, value, options.merge(type: :email))
      end

      def number_field_tag(name, value = nil, options = {})
        options = options.stringify_keys
        options["type"] ||= "number"
        if range = options.delete("in") || options.delete("within")
          options.update("min" => range.min, "max" => range.max)
        end
        text_field_tag(name, value, options)
      end

      def range_field_tag(name, value = nil, options = {})
        number_field_tag(name, value, options.merge(type: :range))
      end

      def utf8_enforcer_tag
        '<input name="utf8" type="hidden" value="&#x2713;" />'.html_safe
      end

      private
        def html_options_for_form(url_for_options, options)
          options.stringify_keys.tap do |html_options|
            html_options["enctype"] = "multipart/form-data" if html_options.delete("multipart")
            html_options["action"]  = url_for(url_for_options)
            html_options["accept-charset"] = "UTF-8"

            html_options["data-remote"] = true if html_options.delete("remote")

            if html_options["data-remote"] &&
               !embed_authenticity_token_in_remote_forms &&
               html_options["authenticity_token"].blank?
              html_options["authenticity_token"] = false
            elsif html_options["authenticity_token"] == true
              html_options["authenticity_token"] = nil
            end
          end
        end

        def extra_tags_for_form(html_options)
          authenticity_token = html_options.delete("authenticity_token")
          method = html_options.delete("method").to_s

          method_tag = case method
            when /^get$/i # must be case-insensitive, but can't use downcase as might be nil
              html_options["method"] = "get"
              ''
            when /^post$/i, "", nil
              html_options["method"] = "post"
              token_tag(authenticity_token)
            else
              html_options["method"] = "post"
              method_tag(method) + token_tag(authenticity_token)
          end

          if html_options.delete("enforce_utf8") { true }
            utf8_enforcer_tag + method_tag
          else
            method_tag
          end
        end

        def form_tag_html(html_options)
          extra_tags = extra_tags_for_form(html_options)
          tag(:form, html_options, true) + extra_tags
        end

        def form_tag_with_body(html_options, content)
          output = form_tag_html(html_options)
          output << content
          output.safe_concat("</form>")
        end

        def sanitize_to_id(name)
          name.to_s.delete(']').tr('^-a-zA-Z0-9:.', "_")
        end
    end
  end
end
