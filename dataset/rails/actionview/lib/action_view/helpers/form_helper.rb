require 'cgi'
require 'action_view/helpers/date_helper'
require 'action_view/helpers/tag_helper'
require 'action_view/helpers/form_tag_helper'
require 'action_view/helpers/active_model_helper'
require 'action_view/model_naming'
require 'active_support/core_ext/module/attribute_accessors'
require 'active_support/core_ext/hash/slice'
require 'active_support/core_ext/string/output_safety'
require 'active_support/core_ext/string/inflections'

module ActionView
  module Helpers
    module FormHelper
      extend ActiveSupport::Concern

      include FormTagHelper
      include UrlHelper
      include ModelNaming

      def form_for(record, options = {}, &block)
        raise ArgumentError, "Missing block" unless block_given?
        html_options = options[:html] ||= {}

        case record
        when String, Symbol
          object_name = record
          object      = nil
        else
          object      = record.is_a?(Array) ? record.last : record
          raise ArgumentError, "First argument in form cannot contain nil or be empty" unless object
          object_name = options[:as] || model_name_from_record_or_class(object).param_key
          apply_form_for_options!(record, object, options)
        end

        html_options[:data]   = options.delete(:data)   if options.has_key?(:data)
        html_options[:remote] = options.delete(:remote) if options.has_key?(:remote)
        html_options[:method] = options.delete(:method) if options.has_key?(:method)
        html_options[:enforce_utf8] = options.delete(:enforce_utf8) if options.has_key?(:enforce_utf8)
        html_options[:authenticity_token] = options.delete(:authenticity_token)

        builder = instantiate_builder(object_name, object, options)
        output  = capture(builder, &block)
        html_options[:multipart] ||= builder.multipart?

        html_options = html_options_for_form(options[:url] || {}, html_options)
        form_tag_with_body(html_options, output)
      end

      def apply_form_for_options!(record, object, options) #:nodoc:
        object = convert_to_model(object)

        as = options[:as]
        namespace = options[:namespace]
        action, method = object.respond_to?(:persisted?) && object.persisted? ? [:edit, :patch] : [:new, :post]
        options[:html].reverse_merge!(
          class:  as ? "#{action}_#{as}" : dom_class(object, action),
          id:     (as ? [namespace, action, as] : [namespace, dom_id(object, action)]).compact.join("_").presence,
          method: method
        )

        options[:url] ||= if options.key?(:format)
                            polymorphic_path(record, format: options.delete(:format))
                          else
                            polymorphic_path(record, {})
                          end
      end
      private :apply_form_for_options!

      def fields_for(record_name, record_object = nil, options = {}, &block)
        builder = instantiate_builder(record_name, record_object, options)
        capture(builder, &block)
      end

      def label(object_name, method, content_or_options = nil, options = nil, &block)
        Tags::Label.new(object_name, method, self, content_or_options, options).render(&block)
      end

      def text_field(object_name, method, options = {})
        Tags::TextField.new(object_name, method, self, options).render
      end

      def password_field(object_name, method, options = {})
        Tags::PasswordField.new(object_name, method, self, options).render
      end

      def hidden_field(object_name, method, options = {})
        Tags::HiddenField.new(object_name, method, self, options).render
      end

      def file_field(object_name, method, options = {})
        Tags::FileField.new(object_name, method, self, options).render
      end

      def text_area(object_name, method, options = {})
        Tags::TextArea.new(object_name, method, self, options).render
      end

      def check_box(object_name, method, options = {}, checked_value = "1", unchecked_value = "0")
        Tags::CheckBox.new(object_name, method, self, checked_value, unchecked_value, options).render
      end

      def radio_button(object_name, method, tag_value, options = {})
        Tags::RadioButton.new(object_name, method, self, tag_value, options).render
      end

      def color_field(object_name, method, options = {})
        Tags::ColorField.new(object_name, method, self, options).render
      end

      def search_field(object_name, method, options = {})
        Tags::SearchField.new(object_name, method, self, options).render
      end

      def telephone_field(object_name, method, options = {})
        Tags::TelField.new(object_name, method, self, options).render
      end
      alias phone_field telephone_field

      def date_field(object_name, method, options = {})
        Tags::DateField.new(object_name, method, self, options).render
      end

      def time_field(object_name, method, options = {})
        Tags::TimeField.new(object_name, method, self, options).render
      end

      def datetime_field(object_name, method, options = {})
        Tags::DatetimeField.new(object_name, method, self, options).render
      end

      def datetime_local_field(object_name, method, options = {})
        Tags::DatetimeLocalField.new(object_name, method, self, options).render
      end

      def month_field(object_name, method, options = {})
        Tags::MonthField.new(object_name, method, self, options).render
      end

      def week_field(object_name, method, options = {})
        Tags::WeekField.new(object_name, method, self, options).render
      end

      def url_field(object_name, method, options = {})
        Tags::UrlField.new(object_name, method, self, options).render
      end

      def email_field(object_name, method, options = {})
        Tags::EmailField.new(object_name, method, self, options).render
      end

      def number_field(object_name, method, options = {})
        Tags::NumberField.new(object_name, method, self, options).render
      end

      def range_field(object_name, method, options = {})
        Tags::RangeField.new(object_name, method, self, options).render
      end

      private

        def instantiate_builder(record_name, record_object, options)
          case record_name
          when String, Symbol
            object = record_object
            object_name = record_name
          else
            object = record_name
            object_name = model_name_from_record_or_class(object).param_key
          end

          builder = options[:builder] || default_form_builder_class
          builder.new(object_name, object, self, options)
        end

        def default_form_builder_class
          builder = ActionView::Base.default_form_builder
          builder.respond_to?(:constantize) ? builder.constantize : builder
        end
    end

    class FormBuilder
      include ModelNaming

      class_attribute :field_helpers
      self.field_helpers = [:fields_for, :label, :text_field, :password_field,
                            :hidden_field, :file_field, :text_area, :check_box,
                            :radio_button, :color_field, :search_field,
                            :telephone_field, :phone_field, :date_field,
                            :time_field, :datetime_field, :datetime_local_field,
                            :month_field, :week_field, :url_field, :email_field,
                            :number_field, :range_field]

      attr_accessor :object_name, :object, :options

      attr_reader :multipart, :index
      alias :multipart? :multipart

      def multipart=(multipart)
        @multipart = multipart

        if parent_builder = @options[:parent_builder]
          parent_builder.multipart = multipart
        end
      end

      def self._to_partial_path
        @_to_partial_path ||= name.demodulize.underscore.sub!(/_builder$/, '')
      end

      def to_partial_path
        self.class._to_partial_path
      end

      def to_model
        self
      end

      def initialize(object_name, object, template, options)
        @nested_child_index = {}
        @object_name, @object, @template, @options = object_name, object, template, options
        @default_options = @options ? @options.slice(:index, :namespace) : {}
        if @object_name.to_s.match(/\[\]$/)
          #nodyna <instance_variable_get-1211> <IVG COMPLEX (change-prone variable)>
          if object ||= @template.instance_variable_get("@#{Regexp.last_match.pre_match}") and object.respond_to?(:to_param)
            @auto_index = object.to_param
          else
            raise ArgumentError, "object[] naming but object param and @object var don't exist or don't respond to to_param: #{object.inspect}"
          end
        end
        @multipart = nil
        @index = options[:index] || options[:child_index]
      end

      (field_helpers - [:label, :check_box, :radio_button, :fields_for, :hidden_field, :file_field]).each do |selector|
        #nodyna <class_eval-1212> <CE MODERATE (define methods)>
        class_eval <<-RUBY_EVAL, __FILE__, __LINE__ + 1
          def #{selector}(method, options = {})  # def text_field(method, options = {})
            #nodyna <send-1213> <SD COMPLEX (change-prone variables)>
            @template.send(                      #   @template.send(
              @object_name,                      #     @object_name,
              method,                            #     method,
              objectify_options(options))        #     objectify_options(options))
          end                                    # end
        RUBY_EVAL
      end

      def fields_for(record_name, record_object = nil, fields_options = {}, &block)
        fields_options, record_object = record_object, nil if record_object.is_a?(Hash) && record_object.extractable_options?
        fields_options[:builder] ||= options[:builder]
        fields_options[:namespace] = options[:namespace]
        fields_options[:parent_builder] = self

        case record_name
        when String, Symbol
          if nested_attributes_association?(record_name)
            return fields_for_with_nested_attributes(record_name, record_object, fields_options, block)
          end
        else
          record_object = record_name.is_a?(Array) ? record_name.last : record_name
          record_name   = model_name_from_record_or_class(record_object).param_key
        end

        index = if options.has_key?(:index)
          options[:index]
        elsif defined?(@auto_index)
          self.object_name = @object_name.to_s.sub(/\[\]$/,"")
          @auto_index
        end

        record_name = index ? "#{object_name}[#{index}][#{record_name}]" : "#{object_name}[#{record_name}]"
        fields_options[:child_index] = index

        @template.fields_for(record_name, record_object, fields_options, &block)
      end

      def label(method, text = nil, options = {}, &block)
        @template.label(@object_name, method, text, objectify_options(options), &block)
      end

      def check_box(method, options = {}, checked_value = "1", unchecked_value = "0")
        @template.check_box(@object_name, method, objectify_options(options), checked_value, unchecked_value)
      end

      def radio_button(method, tag_value, options = {})
        @template.radio_button(@object_name, method, tag_value, objectify_options(options))
      end

      def hidden_field(method, options = {})
        @emitted_hidden_id = true if method == :id
        @template.hidden_field(@object_name, method, objectify_options(options))
      end

      def file_field(method, options = {})
        self.multipart = true
        @template.file_field(@object_name, method, objectify_options(options))
      end

      def submit(value=nil, options={})
        value, options = nil, value if value.is_a?(Hash)
        value ||= submit_default_value
        @template.submit_tag(value, options)
      end

      def button(value = nil, options = {}, &block)
        value, options = nil, value if value.is_a?(Hash)
        value ||= submit_default_value
        @template.button_tag(value, options, &block)
      end

      def emitted_hidden_id?
        @emitted_hidden_id ||= nil
      end

      private
        def objectify_options(options)
          @default_options.merge(options.merge(object: @object))
        end

        def submit_default_value
          object = convert_to_model(@object)
          key    = object ? (object.persisted? ? :update : :create) : :submit

          model = if object.respond_to?(:model_name)
            object.model_name.human
          else
            @object_name.to_s.humanize
          end

          defaults = []
          defaults << :"helpers.submit.#{object_name}.#{key}"
          defaults << :"helpers.submit.#{key}"
          defaults << "#{key.to_s.humanize} #{model}"

          I18n.t(defaults.shift, model: model, default: defaults)
        end

        def nested_attributes_association?(association_name)
          @object.respond_to?("#{association_name}_attributes=")
        end

        def fields_for_with_nested_attributes(association_name, association, options, block)
          name = "#{object_name}[#{association_name}_attributes]"
          association = convert_to_model(association)

          if association.respond_to?(:persisted?)
            #nodyna <send-1215> <SD COMPLEX (change-prone variables)>
            association = [association] if @object.send(association_name).respond_to?(:to_ary)
          elsif !association.respond_to?(:to_ary)
            #nodyna <send-1216> <SD COMPLEX (change-prone variables)>
            association = @object.send(association_name)
          end

          if association.respond_to?(:to_ary)
            explicit_child_index = options[:child_index]
            output = ActiveSupport::SafeBuffer.new
            association.each do |child|
              options[:child_index] = nested_child_index(name) unless explicit_child_index
              output << fields_for_nested_model("#{name}[#{options[:child_index]}]", child, options, block)
            end
            output
          elsif association
            fields_for_nested_model(name, association, options, block)
          end
        end

        def fields_for_nested_model(name, object, fields_options, block)
          object = convert_to_model(object)
          emit_hidden_id = object.persisted? && fields_options.fetch(:include_id) {
            options.fetch(:include_id, true)
          }

          @template.fields_for(name, object, fields_options) do |f|
            output = @template.capture(f, &block)
            output.concat f.hidden_field(:id) if output && emit_hidden_id && !f.emitted_hidden_id?
            output
          end
        end

        def nested_child_index(name)
          @nested_child_index[name] ||= -1
          @nested_child_index[name] += 1
        end
    end
  end

  ActiveSupport.on_load(:action_view) do
    cattr_accessor(:default_form_builder, instance_writer: false, instance_reader: false) do
      ::ActionView::Helpers::FormBuilder
    end
  end
end
