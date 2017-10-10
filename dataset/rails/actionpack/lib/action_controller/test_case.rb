require 'rack/session/abstract/id'
require 'active_support/core_ext/object/to_query'
require 'active_support/core_ext/module/anonymous'
require 'active_support/core_ext/hash/keys'
require 'active_support/deprecation'

require 'rails-dom-testing'

module ActionController
  module TemplateAssertions
    extend ActiveSupport::Concern

    included do
      setup :setup_subscriptions
      teardown :teardown_subscriptions
    end

    RENDER_TEMPLATE_INSTANCE_VARIABLES = %w{partials templates layouts files}.freeze

    def setup_subscriptions
      RENDER_TEMPLATE_INSTANCE_VARIABLES.each do |instance_variable|
        #nodyna <instance_variable_set-1296> <not yet classified>
        instance_variable_set("@_#{instance_variable}", Hash.new(0))
      end

      @_subscribers = []

      @_subscribers << ActiveSupport::Notifications.subscribe("render_template.action_view") do |_name, _start, _finish, _id, payload|
        path = payload[:layout]
        if path
          @_layouts[path] += 1
          if path =~ /^layouts\/(.*)/
            @_layouts[$1] += 1
          end
        end
      end

      @_subscribers << ActiveSupport::Notifications.subscribe("!render_template.action_view") do |_name, _start, _finish, _id, payload|
        if virtual_path = payload[:virtual_path]
          partial = virtual_path =~ /^.*\/_[^\/]*$/

          if partial
            @_partials[virtual_path] += 1
            @_partials[virtual_path.split("/").last] += 1
          end

          @_templates[virtual_path] += 1
        else
          path = payload[:identifier]
          if path
            @_files[path] += 1
            @_files[path.split("/").last] += 1
          end
        end
      end
    end

    def teardown_subscriptions
      @_subscribers.each do |subscriber|
        ActiveSupport::Notifications.unsubscribe(subscriber)
      end
    end

    def process(*args)
      reset_template_assertion
      super
    end

    def reset_template_assertion
      RENDER_TEMPLATE_INSTANCE_VARIABLES.each do |instance_variable|
        ivar_name = "@_#{instance_variable}"
        if instance_variable_defined?(ivar_name)
          #nodyna <instance_variable_get-1297> <not yet classified>
          instance_variable_get(ivar_name).clear
        end
      end
    end

    def assert_template(options = {}, message = nil)
      response.body

      case options
      when NilClass, Regexp, String, Symbol
        options = options.to_s if Symbol === options
        rendered = @_templates
        msg = message || sprintf("expecting <%s> but rendering with <%s>",
                options.inspect, rendered.keys)
        matches_template =
          case options
          when String
            !options.empty? && rendered.any? do |t, num|
              options_splited = options.split(File::SEPARATOR)
              t_splited = t.split(File::SEPARATOR)
              t_splited.last(options_splited.size) == options_splited
            end
          when Regexp
            rendered.any? { |t,num| t.match(options) }
          when NilClass
            rendered.blank?
          end
        assert matches_template, msg
      when Hash
        options.assert_valid_keys(:layout, :partial, :locals, :count, :file)

        if options.key?(:layout)
          expected_layout = options[:layout]
          msg = message || sprintf("expecting layout <%s> but action rendered <%s>",
                  expected_layout, @_layouts.keys)

          case expected_layout
          when String, Symbol
            assert_includes @_layouts.keys, expected_layout.to_s, msg
          when Regexp
            assert(@_layouts.keys.any? {|l| l =~ expected_layout }, msg)
          when nil, false
            assert(@_layouts.empty?, msg)
          end
        end

        if options[:file]
          assert_includes @_files.keys, options[:file]
        elsif options.key?(:file)
          assert @_files.blank?, "expected no files but #{@_files.keys} was rendered"
        end

        if expected_partial = options[:partial]
          if expected_locals = options[:locals]
            if defined?(@_rendered_views)
              view = expected_partial.to_s.sub(/^_/, '').sub(/\/_(?=[^\/]+\z)/, '/')

              partial_was_not_rendered_msg = "expected %s to be rendered but it was not." % view
              assert_includes @_rendered_views.rendered_views, view, partial_was_not_rendered_msg

              msg = 'expecting %s to be rendered with %s but was with %s' % [expected_partial,
                                                                             expected_locals,
                                                                             @_rendered_views.locals_for(view)]
              assert(@_rendered_views.view_rendered?(view, options[:locals]), msg)
            else
              warn "the :locals option to #assert_template is only supported in a ActionView::TestCase"
            end
          elsif expected_count = options[:count]
            actual_count = @_partials[expected_partial]
            msg = message || sprintf("expecting %s to be rendered %s time(s) but rendered %s time(s)",
                     expected_partial, expected_count, actual_count)
            assert(actual_count == expected_count.to_i, msg)
          else
            msg = message || sprintf("expecting partial <%s> but action rendered <%s>",
                    options[:partial], @_partials.keys)
            assert_includes @_partials, expected_partial, msg
          end
        elsif options.key?(:partial)
          assert @_partials.empty?,
            "Expected no partials to be rendered"
        end
      else
        raise ArgumentError, "assert_template only accepts a String, Symbol, Hash, Regexp, or nil"
      end
    end
  end

  class TestRequest < ActionDispatch::TestRequest #:nodoc:
    DEFAULT_ENV = ActionDispatch::TestRequest::DEFAULT_ENV.dup
    DEFAULT_ENV.delete 'PATH_INFO'

    def initialize(env = {})
      super

      self.session = TestSession.new
      self.session_options = TestSession::DEFAULT_OPTIONS.merge(:id => SecureRandom.hex(16))
    end

    def assign_parameters(routes, controller_path, action, parameters = {})
      parameters = parameters.symbolize_keys.merge(:controller => controller_path, :action => action)
      extra_keys = routes.extra_keys(parameters)
      non_path_parameters = get? ? query_parameters : request_parameters
      parameters.each do |key, value|
        if value.is_a?(Array) && (value.frozen? || value.any?(&:frozen?))
          value = value.map{ |v| v.duplicable? ? v.dup : v }
        elsif value.is_a?(Hash) && (value.frozen? || value.any?{ |k,v| v.frozen? })
          value = Hash[value.map{ |k,v| [k, v.duplicable? ? v.dup : v] }]
        elsif value.frozen? && value.duplicable?
          value = value.dup
        end

        if extra_keys.include?(key)
          non_path_parameters[key] = value
        else
          if value.is_a?(Array)
            value = value.map(&:to_param)
          else
            value = value.to_param
          end

          path_parameters[key] = value
        end
      end

      @env.delete("action_dispatch.request.parameters")

      @filtered_parameters = @filtered_env = @filtered_path = nil

      params = self.request_parameters.dup
      %w(controller action only_path).each do |k|
        params.delete(k)
        params.delete(k.to_sym)
      end
      data = params.to_query

      @env['CONTENT_LENGTH'] = data.length.to_s
      @env['rack.input'] = StringIO.new(data)
    end

    def recycle!
      @formats = nil
      @env.delete_if { |k, v| k =~ /^(action_dispatch|rack)\.request/ }
      @env.delete_if { |k, v| k =~ /^action_dispatch\.rescue/ }
      @method = @request_method = nil
      @fullpath = @ip = @remote_ip = @protocol = nil
      @env['action_dispatch.request.query_parameters'] = {}
      @set_cookies ||= {}
      #nodyna <instance_variable_get-1298> <not yet classified>
      @set_cookies.update(Hash[cookie_jar.instance_variable_get("@set_cookies").map{ |k,o| [k,o[:value]] }])
      #nodyna <instance_variable_get-1299> <not yet classified>
      deleted_cookies = cookie_jar.instance_variable_get("@delete_cookies")
      @set_cookies.reject!{ |k,v| deleted_cookies.include?(k) }
      cookie_jar.update(rack_cookies)
      cookie_jar.update(cookies)
      cookie_jar.update(@set_cookies)
      cookie_jar.recycle!
    end

    private

    def default_env
      DEFAULT_ENV
    end
  end

  class TestResponse < ActionDispatch::TestResponse
    def recycle!
      initialize
    end
  end

  class LiveTestResponse < Live::Response
    def recycle!
      @body = nil
      initialize
    end

    def body
      @body ||= super
    end

    alias_method :success?, :successful?

    alias_method :missing?, :not_found?

    alias_method :redirect?, :redirection?

    alias_method :error?, :server_error?
  end

  class TestSession < Rack::Session::Abstract::SessionHash #:nodoc:
    DEFAULT_OPTIONS = Rack::Session::Abstract::ID::DEFAULT_OPTIONS

    def initialize(session = {})
      super(nil, nil)
      @id = SecureRandom.hex(16)
      @data = stringify_keys(session)
      @loaded = true
    end

    def exists?
      true
    end

    def keys
      @data.keys
    end

    def values
      @data.values
    end

    def destroy
      clear
    end

    def fetch(*args, &block)
      @data.fetch(*args, &block)
    end

    private

      def load!
        @id
      end
  end

  class TestCase < ActiveSupport::TestCase
    module Behavior
      extend ActiveSupport::Concern
      include ActionDispatch::TestProcess
      include ActiveSupport::Testing::ConstantLookup
      include Rails::Dom::Testing::Assertions

      attr_reader :response, :request

      module ClassMethods

        def tests(controller_class)
          case controller_class
          when String, Symbol
            self.controller_class = "#{controller_class.to_s.camelize}Controller".constantize
          when Class
            self.controller_class = controller_class
          else
            raise ArgumentError, "controller class must be a String, Symbol, or Class"
          end
        end

        def controller_class=(new_class)
          self._controller_class = new_class
        end

        def controller_class
          if current_controller_class = self._controller_class
            current_controller_class
          else
            self.controller_class = determine_default_controller_class(name)
          end
        end

        def determine_default_controller_class(name)
          determine_constant_from_test_name(name) do |constant|
            Class === constant && constant < ActionController::Metal
          end
        end
      end

      def get(action, *args)
        process(action, "GET", *args)
      end

      def post(action, *args)
        process(action, "POST", *args)
      end

      def patch(action, *args)
        process(action, "PATCH", *args)
      end

      def put(action, *args)
        process(action, "PUT", *args)
      end

      def delete(action, *args)
        process(action, "DELETE", *args)
      end

      def head(action, *args)
        process(action, "HEAD", *args)
      end

      def xml_http_request(request_method, action, parameters = nil, session = nil, flash = nil)
        @request.env['HTTP_X_REQUESTED_WITH'] = 'XMLHttpRequest'
        @request.env['HTTP_ACCEPT'] ||=  [Mime::JS, Mime::HTML, Mime::XML, 'text/xml', Mime::ALL].join(', ')
        __send__(request_method, action, parameters, session, flash).tap do
          @request.env.delete 'HTTP_X_REQUESTED_WITH'
          @request.env.delete 'HTTP_ACCEPT'
        end
      end
      alias xhr :xml_http_request

      def paramify_values(hash_or_array_or_value)
        case hash_or_array_or_value
        when Hash
          Hash[hash_or_array_or_value.map{|key, value| [key, paramify_values(value)] }]
        when Array
          hash_or_array_or_value.map {|i| paramify_values(i)}
        when Rack::Test::UploadedFile, ActionDispatch::Http::UploadedFile
          hash_or_array_or_value
        else
          hash_or_array_or_value.to_param
        end
      end

      def process(action, http_method = 'GET', *args)
        check_required_ivars

        if args.first.is_a?(String) && http_method != 'HEAD'
          @request.env['RAW_POST_DATA'] = args.shift
        end

        parameters, session, flash = args
        parameters ||= {}

        parameters = paramify_values(parameters) if html_format?(parameters)

        @html_document = nil
        @html_scanner_document = nil

        unless @controller.respond_to?(:recycle!)
          @controller.extend(Testing::Functional)
        end

        @request.recycle!
        @response.recycle!
        @controller.recycle!

        @request.env['REQUEST_METHOD'] = http_method

        controller_class_name = @controller.class.anonymous? ?
          "anonymous" :
          @controller.class.controller_path

        @request.assign_parameters(@routes, controller_class_name, action.to_s, parameters)

        @request.session.update(session) if session
        @request.flash.update(flash || {})

        @controller.request  = @request
        @controller.response = @response

        build_request_uri(action, parameters)

        name = @request.parameters[:action]

        @controller.recycle!
        @controller.process(name)

        if cookies = @request.env['action_dispatch.cookies']
          unless @response.committed?
            cookies.write(@response)
          end
        end
        @response.prepare!

        @assigns = @controller.respond_to?(:view_assigns) ? @controller.view_assigns : {}

        if flash_value = @request.flash.to_session_value
          @request.session['flash'] = flash_value
        end

        @response
      end

      def setup_controller_request_and_response
        @controller = nil unless defined? @controller

        response_klass = TestResponse

        if klass = self.class.controller_class
          if klass < ActionController::Live
            response_klass = LiveTestResponse
          end
          unless @controller
            begin
              @controller = klass.new
            rescue
              warn "could not construct controller #{klass}" if $VERBOSE
            end
          end
        end

        @request          = build_request
        @response         = build_response response_klass
        @response.request = @request

        if @controller
          @controller.request = @request
          @controller.params = {}
        end
      end

      def build_request
        TestRequest.new
      end

      def build_response(klass)
        klass.new
      end

      included do
        include ActionController::TemplateAssertions
        include ActionDispatch::Assertions
        class_attribute :_controller_class
        setup :setup_controller_request_and_response
      end

      private

      def document_root_element
        html_document.root
      end

      def check_required_ivars
        [:@routes, :@controller, :@request, :@response].each do |iv_name|
          #nodyna <instance_variable_get-1300> <not yet classified>
          if !instance_variable_defined?(iv_name) || instance_variable_get(iv_name).nil?
            raise "#{iv_name} is nil: make sure you set it in your test's setup method."
          end
        end
      end

      def build_request_uri(action, parameters)
        unless @request.env["PATH_INFO"]
          options = @controller.respond_to?(:url_options) ? @controller.__send__(:url_options).merge(parameters) : parameters
          options.update(
            :action => action,
            :relative_url_root => nil,
            :_recall => @request.path_parameters)

          if route_name = options.delete(:use_route)
            ActiveSupport::Deprecation.warn <<-MSG.squish
              Passing the `use_route` option in functional tests are deprecated.
              Support for this option in the `process` method (and the related
              `get`, `head`, `post`, `patch`, `put` and `delete` helpers) will
              be removed in the next version without replacement.

              Functional tests are essentially unit tests for controllers and
              they should not require knowledge to how the application's routes
              are configured. Instead, you should explicitly pass the appropiate
              params to the `process` method.

              Previously the engines guide also contained an incorrect example
              that recommended using this option to test an engine's controllers
              within the dummy application. That recommendation was incorrect
              and has since been corrected. Instead, you should override the
              `@routes` variable in the test case with `Foo::Engine.routes`. See
              the updated engines guide for details.
            MSG
          end

          url, query_string = @routes.path_for(options, route_name).split("?", 2)

          @request.env["SCRIPT_NAME"] = @controller.config.relative_url_root
          @request.env["PATH_INFO"] = url
          @request.env["QUERY_STRING"] = query_string || ""
        end
      end

      def html_format?(parameters)
        return true unless parameters.key?(:format)
        Mime.fetch(parameters[:format]) { Mime['html'] }.html?
      end
    end

    include Behavior
  end
end
