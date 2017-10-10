require 'action_view'
require 'simple_form/action_view_extensions/form_helper'
require 'simple_form/action_view_extensions/builder'
require 'active_support/core_ext/hash/slice'
require 'active_support/core_ext/hash/except'
require 'active_support/core_ext/hash/reverse_merge'

module SimpleForm
  extend ActiveSupport::Autoload

  autoload :Helpers
  autoload :Wrappers

  eager_autoload do
    autoload :Components
    autoload :ErrorNotification
    autoload :FormBuilder
    autoload :Inputs
  end

  def self.eager_load!
    super
    SimpleForm::Inputs.eager_load!
    SimpleForm::Components.eager_load!
  end

  CUSTOM_INPUT_DEPRECATION_WARN = <<-WARN
%{name} method now accepts a `wrapper_options` argument. The method definition without the argument is deprecated and will be removed in the next Simple Form version. Change your code from:

    def %{name}

to

    def %{name}(wrapper_options)

See https://github.com/plataformatec/simple_form/pull/997 for more information.
  WARN

  @@configured = false

  def self.configured? #:nodoc:
    @@configured
  end


  mattr_accessor :error_method
  @@error_method = :first

  mattr_accessor :error_notification_tag
  @@error_notification_tag = :p

  mattr_accessor :error_notification_class
  @@error_notification_class = :error_notification

  mattr_accessor :collection_label_methods
  @@collection_label_methods = [:to_label, :name, :title, :to_s]

  mattr_accessor :collection_value_methods
  @@collection_value_methods = [:id, :to_s]

  mattr_accessor :collection_wrapper_tag
  @@collection_wrapper_tag = nil

  mattr_accessor :collection_wrapper_class
  @@collection_wrapper_class = nil

  mattr_accessor :item_wrapper_tag
  @@item_wrapper_tag = :span

  mattr_accessor :item_wrapper_class
  @@item_wrapper_class = nil

  mattr_accessor :label_text
  @@label_text = lambda { |label, required, explicit_label| "#{required} #{label}" }

  mattr_accessor :label_class
  @@label_class = nil

  mattr_accessor :boolean_style
  @@boolean_style = :inline

  mattr_accessor :form_class
  @@form_class = :simple_form

  mattr_accessor :generate_additional_classes_for
  @@generate_additional_classes_for = [:wrapper, :label, :input]

  mattr_accessor :required_by_default
  @@required_by_default = true

  mattr_accessor :browser_validations
  @@browser_validations = true

  mattr_accessor :file_methods
  @@file_methods = [:mounted_as, :file?, :public_filename]

  mattr_accessor :input_mappings
  @@input_mappings = nil

  mattr_accessor :wrapper_mappings
  @@wrapper_mappings = nil

  mattr_accessor :custom_inputs_namespaces
  @@custom_inputs_namespaces = []

  mattr_accessor :time_zone_priority
  @@time_zone_priority = nil

  mattr_accessor :country_priority
  @@country_priority = nil

  mattr_accessor :default_input_size
  @@default_input_size = nil

  mattr_accessor :translate_labels
  @@translate_labels = true

  mattr_accessor :inputs_discovery
  @@inputs_discovery = true

  mattr_accessor :cache_discovery
  @@cache_discovery = defined?(Rails) && !Rails.env.development?

  mattr_accessor :button_class
  @@button_class = 'button'

  mattr_accessor :field_error_proc
  @@field_error_proc = proc do |html_tag, instance_tag|
    html_tag
  end

  mattr_accessor :input_class
  @@input_class = nil

  mattr_accessor :include_default_input_wrapper_class
  @@include_default_input_wrapper_class = true

  mattr_accessor :boolean_label_class
  @@boolean_label_class = 'checkbox'

  mattr_accessor :default_wrapper
  @@default_wrapper = :default
  @@wrappers = {} #:nodoc:

  mattr_accessor :i18n_scope
  @@i18n_scope = 'simple_form'

  def self.wrapper(name)
    @@wrappers[name.to_s] or raise WrapperNotFound, "Couldn't find wrapper with name #{name}"
  end

  class WrapperNotFound < StandardError
  end

  def self.wrappers(*args, &block)
    if block_given?
      options                 = args.extract_options!
      name                    = args.first || :default
      @@wrappers[name.to_s]   = build(options, &block)
    else
      @@wrappers
    end
  end

  def self.build(options = {})
    options[:tag] = :div if options[:tag].nil?
    builder = SimpleForm::Wrappers::Builder.new(options)
    yield builder
    SimpleForm::Wrappers::Root.new(builder.to_a, options)
  end

  wrappers class: :input, hint_class: :field_with_hint, error_class: :field_with_errors do |b|
    b.use :html5

    b.use :min_max
    b.use :maxlength
    b.use :placeholder
    b.optional :pattern
    b.optional :readonly

    b.use :label_input
    b.use :hint,  wrap_with: { tag: :span, class: :hint }
    b.use :error, wrap_with: { tag: :span, class: :error }
  end

  def self.additional_classes_for(component)
    generate_additional_classes_for.include?(component) ? yield : []
  end


  def self.default_input_size=(*)
    ActiveSupport::Deprecation.warn "[SIMPLE_FORM] SimpleForm.default_input_size= is deprecated and has no effect", caller
  end

  def self.setup
    @@configured = true
    yield self
  end
end

require 'simple_form/railtie' if defined?(Rails)
