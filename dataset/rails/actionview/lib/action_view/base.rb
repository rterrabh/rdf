require 'active_support/core_ext/module/attr_internal'
require 'active_support/core_ext/module/attribute_accessors'
require 'active_support/ordered_options'
require 'action_view/log_subscriber'
require 'action_view/helpers'
require 'action_view/context'
require 'action_view/template'
require 'action_view/lookup_context'

module ActionView #:nodoc:
  class Base
    include Helpers, ::ERB::Util, Context

    cattr_accessor :field_error_proc
    @@field_error_proc = Proc.new{ |html_tag, instance| "<div class=\"field_with_errors\">#{html_tag}</div>".html_safe }

    cattr_accessor :streaming_completion_on_exception
    @@streaming_completion_on_exception = %("><script>window.location = "/500.html"</script></html>)

    cattr_accessor :prefix_partial_path_with_controller_namespace
    @@prefix_partial_path_with_controller_namespace = true

    cattr_accessor :default_formats

    cattr_accessor :raise_on_missing_translations
    @@raise_on_missing_translations = false

    class_attribute :_routes
    class_attribute :logger

    class << self
      delegate :erb_trim_mode=, :to => 'ActionView::Template::Handlers::ERB'

      def cache_template_loading
        ActionView::Resolver.caching?
      end

      def cache_template_loading=(value)
        ActionView::Resolver.caching = value
      end

      def xss_safe? #:nodoc:
        true
      end
    end

    attr_accessor :view_renderer
    attr_internal :config, :assigns

    delegate :lookup_context, :to => :view_renderer
    delegate :formats, :formats=, :locale, :locale=, :view_paths, :view_paths=, :to => :lookup_context

    def assign(new_assigns) # :nodoc:
      #nodyna <instance_variable_set-1196> <IVS COMPLEX (array)>
      @_assigns = new_assigns.each { |key, value| instance_variable_set("@#{key}", value) }
    end

    def initialize(context = nil, assigns = {}, controller = nil, formats = nil) #:nodoc:
      @_config = ActiveSupport::InheritableOptions.new

      if context.is_a?(ActionView::Renderer)
        @view_renderer = context
      else
        lookup_context = context.is_a?(ActionView::LookupContext) ?
          context : ActionView::LookupContext.new(context)
        lookup_context.formats  = formats if formats
        lookup_context.prefixes = controller._prefixes if controller
        @view_renderer = ActionView::Renderer.new(lookup_context)
      end

      assign(assigns)
      assign_controller(controller)
      _prepare_context
    end

    ActiveSupport.run_load_hooks(:action_view, self)
  end
end
