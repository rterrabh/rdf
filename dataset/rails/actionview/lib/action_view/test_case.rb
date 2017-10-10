require 'active_support/core_ext/module/remove_method'
require 'action_controller'
require 'action_controller/test_case'
require 'action_view'

require 'rails-dom-testing'

module ActionView
  class TestCase < ActiveSupport::TestCase
    class TestController < ActionController::Base
      include ActionDispatch::TestProcess

      attr_accessor :request, :response, :params

      class << self
        attr_writer :controller_path
      end

      def controller_path=(path)
        self.class.controller_path=(path)
      end

      def initialize
        super
        self.class.controller_path = ""
        @request = ActionController::TestRequest.new
        @response = ActionController::TestResponse.new

        @request.env.delete('PATH_INFO')
        @params = {}
      end
    end

    module Behavior
      extend ActiveSupport::Concern

      include ActionDispatch::Assertions, ActionDispatch::TestProcess
      include Rails::Dom::Testing::Assertions
      include ActionController::TemplateAssertions
      include ActionView::Context

      include ActionDispatch::Routing::PolymorphicRoutes

      include AbstractController::Helpers
      include ActionView::Helpers
      include ActionView::RecordIdentifier
      include ActionView::RoutingUrlFor

      include ActiveSupport::Testing::ConstantLookup

      delegate :lookup_context, :to => :controller
      attr_accessor :controller, :output_buffer, :rendered

      module ClassMethods
        def tests(helper_class)
          case helper_class
          when String, Symbol
            self.helper_class = "#{helper_class.to_s.underscore}_helper".camelize.safe_constantize
          when Module
            self.helper_class = helper_class
          end
        end

        def determine_default_helper_class(name)
          determine_constant_from_test_name(name) do |constant|
            Module === constant && !(Class === constant)
          end
        end

        def helper_method(*methods)
          methods.flatten.each do |method|
            #nodyna <module_eval-1201> <not yet classified>
            _helpers.module_eval <<-end_eval
              def #{method}(*args, &block)                    # def current_user(*args, &block)
                #nodyna <send-1202> <not yet classified>
                _test_case.send(%(#{method}), *args, &block)  #   _test_case.send(%(current_user), *args, &block)
              end                                             # end
            end_eval
          end
        end

        attr_writer :helper_class

        def helper_class
          @helper_class ||= determine_default_helper_class(name)
        end

        def new(*)
          include_helper_modules!
          super
        end

      private

        def include_helper_modules!
          helper(helper_class) if helper_class
          include _helpers
        end

      end

      def setup_with_controller
        @controller = ActionView::TestCase::TestController.new
        @request = @controller.request
        @output_buffer = ActiveSupport::SafeBuffer.new ''
        @rendered = ''

        make_test_case_available_to_view!
        say_no_to_protect_against_forgery!
      end

      def config
        @controller.config if @controller.respond_to?(:config)
      end

      def render(options = {}, local_assigns = {}, &block)
        view.assign(view_assigns)
        @rendered << output = view.render(options, local_assigns, &block)
        output
      end

      def rendered_views
        @_rendered_views ||= RenderedViewsCollection.new
      end

      class RenderedViewsCollection
        def initialize
          @rendered_views ||= Hash.new { |hash, key| hash[key] = [] }
        end

        def add(view, locals)
          @rendered_views[view] ||= []
          @rendered_views[view] << locals
        end

        def locals_for(view)
          @rendered_views[view]
        end

        def rendered_views
          @rendered_views.keys
        end

        def view_rendered?(view, expected_locals)
          locals_for(view).any? do |actual_locals|
            expected_locals.all? {|key, value| value == actual_locals[key] }
          end
        end
      end

      included do
        setup :setup_with_controller
      end

    private

      def document_root_element
        Nokogiri::HTML::Document.parse(@rendered.blank? ? @output_buffer : @rendered).root
      end

      def say_no_to_protect_against_forgery!
        #nodyna <module_eval-1203> <not yet classified>
        _helpers.module_eval do
          remove_possible_method :protect_against_forgery?
          def protect_against_forgery?
            false
          end
        end
      end

      def make_test_case_available_to_view!
        test_case_instance = self
        #nodyna <module_eval-1204> <not yet classified>
        _helpers.module_eval do
          unless private_method_defined?(:_test_case)
            #nodyna <define_method-1205> <DM MODERATE (events)>
            define_method(:_test_case) { test_case_instance }
            private :_test_case
          end
        end
      end

      module Locals
        attr_accessor :rendered_views

        def render(options = {}, local_assigns = {})
          case options
          when Hash
            if block_given?
              rendered_views.add options[:layout], options[:locals]
            elsif options.key?(:partial)
              rendered_views.add options[:partial], options[:locals]
            end
          else
            rendered_views.add options, local_assigns
          end

          super
        end
      end

      def view
        @view ||= begin
          view = @controller.view_context
          #nodyna <send-1206> <SD TRIVIAL (public methods)>
          view.singleton_class.send :include, _helpers
          view.extend(Locals)
          view.rendered_views = self.rendered_views
          view.output_buffer = self.output_buffer
          view
        end
      end

      alias_method :_view, :view

      INTERNAL_IVARS = [
        :@NAME,
        :@failures,
        :@assertions,
        :@__io__,
        :@_assertion_wrapped,
        :@_assertions,
        :@_result,
        :@_routes,
        :@controller,
        :@_layouts,
        :@_files,
        :@_rendered_views,
        :@method_name,
        :@output_buffer,
        :@_partials,
        :@passed,
        :@rendered,
        :@request,
        :@routes,
        :@tagged_logger,
        :@_templates,
        :@options,
        :@test_passed,
        :@view,
        :@view_context_class,
        :@_subscribers,
        :@html_document,
        :@html_scanner_document
      ]

      def _user_defined_ivars
        instance_variables - INTERNAL_IVARS
      end

      def view_assigns
        Hash[_user_defined_ivars.map do |ivar|
          #nodyna <instance_variable_get-1207> <not yet classified>
          [ivar[1..-1].to_sym, instance_variable_get(ivar)]
        end]
      end

      def _routes
        @controller._routes if @controller.respond_to?(:_routes)
      end

      def method_missing(selector, *args)
        if @controller.respond_to?(:_routes) &&
          ( @controller._routes.named_routes.route_defined?(selector) ||
            @controller._routes.mounted_helpers.method_defined?(selector) )
          @controller.__send__(selector, *args)
        else
          super
        end
      end
    end

    include Behavior
  end
end
