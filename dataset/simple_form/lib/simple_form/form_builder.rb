require 'active_support/core_ext/object/deep_dup'
require 'simple_form/map_type'
require 'simple_form/tags'

module SimpleForm
  class FormBuilder < ActionView::Helpers::FormBuilder
    attr_reader :template, :object_name, :object, :wrapper

    ACTIONS = {
      'create' => 'new',
      'update' => 'edit'
    }

    ATTRIBUTE_COMPONENTS = [:html5, :min_max, :maxlength, :placeholder, :pattern, :readonly]

    extend MapType
    include SimpleForm::Inputs

    map_type :text,                                       to: SimpleForm::Inputs::TextInput
    map_type :file,                                       to: SimpleForm::Inputs::FileInput
    map_type :string, :email, :search, :tel, :url, :uuid, to: SimpleForm::Inputs::StringInput
    map_type :password,                                   to: SimpleForm::Inputs::PasswordInput
    map_type :integer, :decimal, :float,                  to: SimpleForm::Inputs::NumericInput
    map_type :range,                                      to: SimpleForm::Inputs::RangeInput
    map_type :check_boxes,                                to: SimpleForm::Inputs::CollectionCheckBoxesInput
    map_type :radio_buttons,                              to: SimpleForm::Inputs::CollectionRadioButtonsInput
    map_type :select,                                     to: SimpleForm::Inputs::CollectionSelectInput
    map_type :grouped_select,                             to: SimpleForm::Inputs::GroupedCollectionSelectInput
    map_type :date, :time, :datetime,                     to: SimpleForm::Inputs::DateTimeInput
    map_type :country, :time_zone,                        to: SimpleForm::Inputs::PriorityInput
    map_type :boolean,                                    to: SimpleForm::Inputs::BooleanInput

    def self.discovery_cache
      @discovery_cache ||= {}
    end

    def initialize(*) #:nodoc:
      super
      @defaults = options[:defaults]
      @wrapper  = SimpleForm.wrapper(options[:wrapper] || SimpleForm.default_wrapper)
    end

    def input(attribute_name, options = {}, &block)
      options = @defaults.deep_dup.deep_merge(options) if @defaults

      input   = find_input(attribute_name, options, &block)
      wrapper = find_wrapper(input.input_type, options)

      wrapper.render input
    end
    alias :attribute :input

    def input_field(attribute_name, options = {})
      options = options.dup
      options[:input_html] = options.except(:as, :boolean_style, :collection, :label_method, :value_method, *ATTRIBUTE_COMPONENTS)
      options = @defaults.deep_dup.deep_merge(options) if @defaults

      input      = find_input(attribute_name, options)
      wrapper    = find_wrapper(input.input_type, options)
      components = (wrapper.components.map(&:namespace) & ATTRIBUTE_COMPONENTS) + [:input]
      components = components.map { |component| SimpleForm::Wrappers::Leaf.new(component) }

      SimpleForm::Wrappers::Root.new(components, wrapper.options.merge(wrapper: false)).render input
    end

    def association(association, options = {}, &block)
      options = options.dup

      return simple_fields_for(*[association,
        options.delete(:collection), options].compact, &block) if block_given?

      raise ArgumentError, "Association cannot be used in forms not associated with an object" unless @object

      reflection = find_association_reflection(association)
      raise "Association #{association.inspect} not found" unless reflection

      options[:as] ||= :select
      options[:collection] ||= fetch_association_collection(reflection, options)

      attribute = build_association_attribute(reflection, association, options)

      input(attribute, options.merge(reflection: reflection))
    end

    alias_method :button_button, :button
    def button(type, *args, &block)
      options = args.extract_options!.dup
      options[:class] = [SimpleForm.button_class, options[:class]].compact
      args << options
      if respond_to?("#{type}_button")
        #nodyna <send-3042> <not yet classified>
        send("#{type}_button", *args, &block)
      else
        #nodyna <send-3043> <not yet classified>
        send(type, *args, &block)
      end
    end

    def error(attribute_name, options = {})
      options = options.dup

      options[:error_html] = options.except(:error_tag, :error_prefix, :error_method)
      column      = find_attribute_column(attribute_name)
      input_type  = default_input_type(attribute_name, column, options)
      wrapper.find(:error).
        render(SimpleForm::Inputs::Base.new(self, attribute_name, column, input_type, options))
    end

    def full_error(attribute_name, options = {})
      options = options.dup

      options[:error_prefix] ||= if object.class.respond_to?(:human_attribute_name)
        object.class.human_attribute_name(attribute_name.to_s)
      else
        attribute_name.to_s.humanize
      end

      error(attribute_name, options)
    end

    def hint(attribute_name, options = {})
      options = options.dup

      options[:hint_html] = options.except(:hint_tag, :hint)
      if attribute_name.is_a?(String)
        options[:hint] = attribute_name
        attribute_name, column, input_type = nil, nil, nil
      else
        column      = find_attribute_column(attribute_name)
        input_type  = default_input_type(attribute_name, column, options)
      end

      wrapper.find(:hint).
        render(SimpleForm::Inputs::Base.new(self, attribute_name, column, input_type, options))
    end

    def label(attribute_name, *args)
      return super if args.first.is_a?(String) || block_given?

      options = args.extract_options!.dup
      options[:label_html] = options.except(:label, :required, :as)

      column      = find_attribute_column(attribute_name)
      input_type  = default_input_type(attribute_name, column, options)
      SimpleForm::Inputs::Base.new(self, attribute_name, column, input_type, options).label
    end

    def error_notification(options = {})
      SimpleForm::ErrorNotification.new(self, options).render
    end

    def collection_radio_buttons(method, collection, value_method, text_method, options = {}, html_options = {}, &block)
      SimpleForm::Tags::CollectionRadioButtons.new(@object_name, method, @template, collection, value_method, text_method, objectify_options(options), @default_options.merge(html_options)).render(&block)
    end

    def collection_check_boxes(method, collection, value_method, text_method, options = {}, html_options = {}, &block)
      SimpleForm::Tags::CollectionCheckBoxes.new(@object_name, method, @template, collection, value_method, text_method, objectify_options(options), @default_options.merge(html_options)).render(&block)
    end

    def lookup_model_names #:nodoc:
      @lookup_model_names ||= begin
        child_index = options[:child_index]
        names = object_name.to_s.scan(/(?!\d)\w+/).flatten
        names.delete(child_index) if child_index
        names.each { |name| name.gsub!('_attributes', '') }
        names.freeze
      end
    end

    def lookup_action #:nodoc:
      @lookup_action ||= begin
        action = template.controller && template.controller.action_name
        return unless action
        action = action.to_s
        ACTIONS[action] || action
      end
    end

    private

    def fetch_association_collection(reflection, options)
      options.fetch(:collection) do
        relation = reflection.klass.all

        if reflection.respond_to?(:scope) && reflection.scope
          #nodyna <instance_exec-3044> <not yet classified>
          relation = reflection.klass.instance_exec(&reflection.scope)
        else
          order = reflection.options[:order]
          conditions = reflection.options[:conditions]
          #nodyna <instance_exec-3045> <not yet classified>
          conditions = object.instance_exec(&conditions) if conditions.respond_to?(:call)

          relation = relation.where(conditions)
          relation = relation.order(order) if relation.respond_to?(:order)
        end

        relation
      end
    end

    def build_association_attribute(reflection, association, options)
      case reflection.macro
      when :belongs_to
        (reflection.respond_to?(:options) && reflection.options[:foreign_key]) || :"#{reflection.name}_id"
      when :has_one
        raise ArgumentError, ":has_one associations are not supported by f.association"
      else
        if options[:as] == :select
          html_options = options[:input_html] ||= {}
          html_options[:multiple] = true unless html_options.key?(:multiple)
        end

        if options[:preload] != false && object.respond_to?(association)
          #nodyna <send-3046> <not yet classified>
          target = object.send(association)
          target.to_a if target.respond_to?(:to_a)
        end

        :"#{reflection.name.to_s.singularize}_ids"
      end
    end

    def find_input(attribute_name, options = {}, &block)
      column     = find_attribute_column(attribute_name)
      input_type = default_input_type(attribute_name, column, options)

      if block_given?
        SimpleForm::Inputs::BlockInput.new(self, attribute_name, column, input_type, options, &block)
      else
        find_mapping(input_type).new(self, attribute_name, column, input_type, options)
      end
    end

    def default_input_type(attribute_name, column, options)
      return options[:as].to_sym if options[:as]
      return :select             if options[:collection]
      custom_type = find_custom_type(attribute_name.to_s) and return custom_type

      input_type = column.try(:type)
      case input_type
      when :timestamp
        :datetime
      when :string, nil
        case attribute_name.to_s
        when /password/  then :password
        when /time_zone/ then :time_zone
        when /country/   then :country
        when /email/     then :email
        when /phone/     then :tel
        when /url/       then :url
        else
          file_method?(attribute_name) ? :file : (input_type || :string)
        end
      else
        input_type
      end
    end

    def find_custom_type(attribute_name)
      SimpleForm.input_mappings.find { |match, type|
        attribute_name =~ match
      }.try(:last) if SimpleForm.input_mappings
    end

    def file_method?(attribute_name)
      #nodyna <send-3047> <not yet classified>
      file = @object.send(attribute_name) if @object.respond_to?(attribute_name)
      file && SimpleForm.file_methods.any? { |m| file.respond_to?(m) }
    end

    def find_attribute_column(attribute_name)
      if @object.respond_to?(:column_for_attribute)
        @object.column_for_attribute(attribute_name)
      end
    end

    def find_association_reflection(association)
      if @object.class.respond_to?(:reflect_on_association)
        @object.class.reflect_on_association(association)
      end
    end

    def find_mapping(input_type)
      discovery_cache[input_type] ||=
        if mapping = self.class.mappings[input_type]
          mapping_override(mapping) || mapping
        else
          camelized = "#{input_type.to_s.camelize}Input"
          attempt_mapping_with_custom_namespace(camelized) ||
            attempt_mapping(camelized, Object) ||
            attempt_mapping(camelized, self.class) ||
            raise("No input found for #{input_type}")
        end
    end

    def find_wrapper_mapping(input_type)
      if options[:wrapper_mappings] && options[:wrapper_mappings][input_type]
        options[:wrapper_mappings][input_type]
      else
        SimpleForm.wrapper_mappings && SimpleForm.wrapper_mappings[input_type]
      end
    end

    def find_wrapper(input_type, options)
      if name = options[:wrapper] || find_wrapper_mapping(input_type)
        name.respond_to?(:render) ? name : SimpleForm.wrapper(name)
      else
        wrapper
      end
    end

    def discovery_cache
      if SimpleForm.cache_discovery
        self.class.discovery_cache
      else
        @discovery_cache ||= {}
      end
    end

    def mapping_override(klass)
      name = klass.name
      if name =~ /^SimpleForm::Inputs/
        input_name = name.split("::").last
        attempt_mapping_with_custom_namespace(input_name) ||
          attempt_mapping(input_name, Object)
      end
    end

    def attempt_mapping(mapping, at)
      return if SimpleForm.inputs_discovery == false && at == Object

      begin
        #nodyna <const_get-3048> <not yet classified>
        at.const_get(mapping)
      rescue NameError => e
        raise if e.message !~ /#{mapping}$/
      end
    end

    def attempt_mapping_with_custom_namespace(input_name)
      SimpleForm.custom_inputs_namespaces.each do |namespace|
        if (mapping = attempt_mapping(input_name, namespace.constantize))
          return mapping
        end
      end

      nil
    end
  end
end
