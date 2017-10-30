require 'stringio'
require 'uri'
require 'active_support/core_ext/kernel/singleton_class'
require 'active_support/core_ext/object/try'
require 'rack/test'
require 'minitest'

module ActionDispatch
  module Integration #:nodoc:
    module RequestHelpers
      def get(path, parameters = nil, headers_or_env = nil)
        process :get, path, parameters, headers_or_env
      end

      def post(path, parameters = nil, headers_or_env = nil)
        process :post, path, parameters, headers_or_env
      end

      def patch(path, parameters = nil, headers_or_env = nil)
        process :patch, path, parameters, headers_or_env
      end

      def put(path, parameters = nil, headers_or_env = nil)
        process :put, path, parameters, headers_or_env
      end

      def delete(path, parameters = nil, headers_or_env = nil)
        process :delete, path, parameters, headers_or_env
      end

      def head(path, parameters = nil, headers_or_env = nil)
        process :head, path, parameters, headers_or_env
      end

      def xml_http_request(request_method, path, parameters = nil, headers_or_env = nil)
        headers_or_env ||= {}
        headers_or_env['HTTP_X_REQUESTED_WITH'] = 'XMLHttpRequest'
        headers_or_env['HTTP_ACCEPT'] ||= [Mime::JS, Mime::HTML, Mime::XML, 'text/xml', Mime::ALL].join(', ')
        process(request_method, path, parameters, headers_or_env)
      end
      alias xhr :xml_http_request

      def follow_redirect!
        raise "not a redirect! #{status} #{status_message}" unless redirect?
        get(response.location)
        status
      end

      def request_via_redirect(http_method, path, parameters = nil, headers_or_env = nil)
        process(http_method, path, parameters, headers_or_env)
        follow_redirect! while redirect?
        status
      end

      def get_via_redirect(path, parameters = nil, headers_or_env = nil)
        request_via_redirect(:get, path, parameters, headers_or_env)
      end

      def post_via_redirect(path, parameters = nil, headers_or_env = nil)
        request_via_redirect(:post, path, parameters, headers_or_env)
      end

      def patch_via_redirect(path, parameters = nil, headers_or_env = nil)
        request_via_redirect(:patch, path, parameters, headers_or_env)
      end

      def put_via_redirect(path, parameters = nil, headers_or_env = nil)
        request_via_redirect(:put, path, parameters, headers_or_env)
      end

      def delete_via_redirect(path, parameters = nil, headers_or_env = nil)
        request_via_redirect(:delete, path, parameters, headers_or_env)
      end
    end

    class Session
      DEFAULT_HOST = "www.example.com"

      include Minitest::Assertions
      include TestProcess, RequestHelpers, Assertions

      %w( status status_message headers body redirect? ).each do |method|
        delegate method, :to => :response, :allow_nil => true
      end

      %w( path ).each do |method|
        delegate method, :to => :request, :allow_nil => true
      end

      def host
        @host || DEFAULT_HOST
      end
      attr_writer :host

      attr_accessor :remote_addr

      attr_accessor :accept

      def cookies
        _mock_session.cookie_jar
      end

      attr_reader :controller

      attr_reader :request

      attr_reader :response

      attr_accessor :request_count

      include ActionDispatch::Routing::UrlFor

      def initialize(app)
        super()
        @app = app

        if app.respond_to?(:routes)
          #nodyna <class_eval-1288> <CE TRIVIAL (block execution)>
          singleton_class.class_eval do
            include app.routes.url_helpers
            include app.routes.mounted_helpers
          end
        end

        reset!
      end

      def url_options
        @url_options ||= default_url_options.dup.tap do |url_options|
          url_options.reverse_merge!(controller.url_options) if controller

          if @app.respond_to?(:routes)
            url_options.reverse_merge!(@app.routes.default_url_options)
          end

          url_options.reverse_merge!(:host => host, :protocol => https? ? "https" : "http")
        end
      end

      def reset!
        @https = false
        @controller = @request = @response = nil
        @_mock_session = nil
        @request_count = 0
        @url_options = nil

        self.host        = DEFAULT_HOST
        self.remote_addr = "127.0.0.1"
        self.accept      = "text/xml,application/xml,application/xhtml+xml," +
                           "text/html;q=0.9,text/plain;q=0.8,image/png," +
                           "*/*;q=0.5"

        unless defined? @named_routes_configured
          @named_routes_configured = true
        end
      end

      def https!(flag = true)
        @https = flag
      end

      def https?
        @https
      end

      alias :host! :host=

      private
        def _mock_session
          @_mock_session ||= Rack::MockSession.new(@app, host)
        end

        def process(method, path, parameters = nil, headers_or_env = nil)
          if path =~ %r{://}
            location = URI.parse(path)
            https! URI::HTTPS === location if location.scheme
            host! "#{location.host}:#{location.port}" if location.host
            path = location.query ? "#{location.path}?#{location.query}" : location.path
          end

          hostname, port = host.split(':')

          env = {
            :method => method,
            :params => parameters,

            "SERVER_NAME"     => hostname,
            "SERVER_PORT"     => port || (https? ? "443" : "80"),
            "HTTPS"           => https? ? "on" : "off",
            "rack.url_scheme" => https? ? "https" : "http",

            "REQUEST_URI"    => path,
            "HTTP_HOST"      => host,
            "REMOTE_ADDR"    => remote_addr,
            "CONTENT_TYPE"   => "application/x-www-form-urlencoded",
            "HTTP_ACCEPT"    => accept
          }
          Http::Headers.new(env).merge!(headers_or_env || {})

          session = Rack::Test::Session.new(_mock_session)

          session.request(build_full_uri(path, env), env)

          @request_count += 1
          @request  = ActionDispatch::Request.new(session.last_request.env)
          response = _mock_session.last_response
          @response = ActionDispatch::TestResponse.from_response(response)
          @html_document = nil
          @html_scanner_document = nil
          @url_options = nil

          @controller = session.last_request.env['action_controller.instance']

          return response.status
        end

        def build_full_uri(path, env)
          "#{env['rack.url_scheme']}://#{env['SERVER_NAME']}:#{env['SERVER_PORT']}#{path}"
        end
    end

    module Runner
      include ActionDispatch::Assertions

      def app
        @app ||= nil
      end

      def reset!
        @integration_session = Integration::Session.new(app)
      end

      def remove! # :nodoc:
        @integration_session = nil
      end

      %w(get post patch put head delete cookies assigns
         xml_http_request xhr get_via_redirect post_via_redirect).each do |method|
        #nodyna <define_method-1289> <DM MODERATE (array)>
        define_method(method) do |*args|
          reset! unless integration_session

          unless method == 'cookies' || method == 'assigns'
            @html_document = nil
            @html_scanner_document = nil
            reset_template_assertion
          end

          integration_session.__send__(method, *args).tap do
            copy_session_variables!
          end
        end
      end

      def open_session
        dup.tap do |session|
          yield session if block_given?
        end
      end

      def copy_session_variables! #:nodoc:
        return unless integration_session
        %w(controller response request).each do |var|
          #nodyna <instance_variable_set-1290> <IVS MODERATE (array)>
          instance_variable_set("@#{var}", @integration_session.__send__(var))
        end
      end

      def default_url_options
        reset! unless integration_session
        integration_session.default_url_options
      end

      def default_url_options=(options)
        reset! unless integration_session
        integration_session.default_url_options = options
      end

      def respond_to?(method, include_private = false)
        integration_session.respond_to?(method, include_private) || super
      end

      def method_missing(sym, *args, &block)
        reset! unless integration_session
        if integration_session.respond_to?(sym)
          integration_session.__send__(sym, *args, &block).tap do
            copy_session_variables!
          end
        else
          super
        end
      end

      private
        def integration_session
          @integration_session ||= nil
        end
    end
  end

  class IntegrationTest < ActiveSupport::TestCase
    include Integration::Runner
    include ActionController::TemplateAssertions
    include ActionDispatch::Routing::UrlFor

    @@app = nil

    def self.app
      @@app || ActionDispatch.test_app
    end

    def self.app=(app)
      @@app = app
    end

    def app
      super || self.class.app
    end

    def url_options
      reset! unless integration_session
      integration_session.url_options
    end

    def document_root_element
      html_document.root
    end
  end
end
