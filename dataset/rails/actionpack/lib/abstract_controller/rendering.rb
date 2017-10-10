require 'active_support/concern'
require 'active_support/core_ext/class/attribute'
require 'action_view'
require 'action_view/view_paths'
require 'set'

module AbstractController
  class DoubleRenderError < Error
    DEFAULT_MESSAGE = "Render and/or redirect were called multiple times in this action. Please note that you may only call render OR redirect, and at most once per action. Also note that neither redirect nor render terminate execution of the action, so if you want to exit an action after redirecting, you need to do something like \"redirect_to(...) and return\"."

    def initialize(message = nil)
      super(message || DEFAULT_MESSAGE)
    end
  end

  module Rendering
    extend ActiveSupport::Concern
    include ActionView::ViewPaths

    def render(*args, &block)
      options = _normalize_render(*args, &block)
      self.response_body = render_to_body(options)
      _process_format(rendered_format, options) if rendered_format
      self.response_body
    end

    def render_to_string(*args, &block)
      options = _normalize_render(*args, &block)
      render_to_body(options)
    end

    def render_to_body(options = {})
    end

    def rendered_format
      Mime::TEXT
    end

    DEFAULT_PROTECTED_INSTANCE_VARIABLES = Set.new %w(
      @_action_name @_response_body @_formats @_prefixes @_config
      @_view_context_class @_view_renderer @_lookup_context
      @_routes @_db_runtime
    ).map(&:to_sym)

    def view_assigns
      protected_vars = _protected_ivars
      variables      = instance_variables

      variables.reject! { |s| protected_vars.include? s }
      variables.each_with_object({}) { |name, hash|
        #nodyna <instance_variable_get-1317> <not yet classified>
        hash[name.slice(1, name.length)] = instance_variable_get(name)
      }
    end

    def _normalize_args(action=nil, options={})
      if action.is_a? Hash
        action
      else
        options
      end
    end

    def _normalize_options(options)
      options
    end

    def _process_options(options)
      options
    end

    def _process_format(format, options = {})
    end

    def _normalize_render(*args, &block)
      options = _normalize_args(*args, &block)
      if defined?(request) && request && request.variant.present?
        options[:variant] = request.variant
      end
      _normalize_options(options)
      options
    end

    def _protected_ivars # :nodoc:
      DEFAULT_PROTECTED_INSTANCE_VARIABLES
    end
  end
end
