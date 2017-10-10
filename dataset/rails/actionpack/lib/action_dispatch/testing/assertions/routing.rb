require 'uri'
require 'active_support/core_ext/hash/indifferent_access'
require 'active_support/core_ext/string/access'
require 'action_controller/metal/exceptions'

module ActionDispatch
  module Assertions
    module RoutingAssertions
      def assert_recognizes(expected_options, path, extras={}, msg=nil)
        if path.is_a?(Hash) && path[:method].to_s == "all"
          [:get, :post, :put, :delete].each do |method|
            assert_recognizes(expected_options, path.merge(method: method), extras, msg)
          end
        else
          request = recognized_request_for(path, extras, msg)

          expected_options = expected_options.clone

          expected_options.stringify_keys!

          msg = message(msg, "") {
            sprintf("The recognized options <%s> did not match <%s>, difference:",
                    request.path_parameters, expected_options)
          }

          assert_equal(expected_options, request.path_parameters, msg)
        end
      end

      def assert_generates(expected_path, options, defaults={}, extras={}, message=nil)
        if expected_path =~ %r{://}
          fail_on(URI::InvalidURIError, message) do
            uri = URI.parse(expected_path)
            expected_path = uri.path.to_s.empty? ? "/" : uri.path
          end
        else
          expected_path = "/#{expected_path}" unless expected_path.first == '/'
        end

        generated_path, extra_keys = @routes.generate_extras(options, defaults)
        found_extras = options.reject { |k, _| ! extra_keys.include? k }

        msg = message || sprintf("found extras <%s>, not <%s>", found_extras, extras)
        assert_equal(extras, found_extras, msg)

        msg = message || sprintf("The generated path <%s> did not match <%s>", generated_path,
            expected_path)
        assert_equal(expected_path, generated_path, msg)
      end

      def assert_routing(path, options, defaults={}, extras={}, message=nil)
        assert_recognizes(options, path, extras, message)

        controller, default_controller = options[:controller], defaults[:controller]
        if controller && controller.include?(?/) && default_controller && default_controller.include?(?/)
          options[:controller] = "/#{controller}"
        end

        generate_options = options.dup.delete_if{ |k, _| defaults.key?(k) }
        assert_generates(path.is_a?(Hash) ? path[:path] : path, generate_options, defaults, extras, message)
      end

      def with_routing
        old_routes, @routes = @routes, ActionDispatch::Routing::RouteSet.new
        if defined?(@controller) && @controller
          old_controller, @controller = @controller, @controller.clone
          _routes = @routes

          #nodyna <send-1292> <SD TRIVIAL (public methods)>
          @controller.singleton_class.send(:include, _routes.url_helpers)
          @controller.view_context_class = Class.new(@controller.view_context_class) do
            include _routes.url_helpers
          end
        end
        yield @routes
      ensure
        @routes = old_routes
        if defined?(@controller) && @controller
          @controller = old_controller
        end
      end

      def method_missing(selector, *args, &block)
        if defined?(@controller) && @controller && defined?(@routes) && @routes && @routes.named_routes.route_defined?(selector)
          #nodyna <send-1293> <SD COMPLEX (change-prone variables)>
          @controller.send(selector, *args, &block)
        else
          super
        end
      end

      private
        def recognized_request_for(path, extras = {}, msg)
          if path.is_a?(Hash)
            method = path[:method]
            path   = path[:path]
          else
            method = :get
          end

          request = ActionController::TestRequest.new

          if path =~ %r{://}
            fail_on(URI::InvalidURIError, msg) do
              uri = URI.parse(path)
              request.env["rack.url_scheme"] = uri.scheme || "http"
              request.host = uri.host if uri.host
              request.port = uri.port if uri.port
              request.path = uri.path.to_s.empty? ? "/" : uri.path
            end
          else
            path = "/#{path}" unless path.first == "/"
            request.path = path
          end

          request.request_method = method if method

          params = fail_on(ActionController::RoutingError, msg) do
            @routes.recognize_path(path, { :method => method, :extras => extras })
          end
          request.path_parameters = params.with_indifferent_access

          request
        end

        def fail_on(exception_class, message)
          yield
        rescue exception_class => e
          raise Minitest::Assertion, message || e.message
        end
    end
  end
end
