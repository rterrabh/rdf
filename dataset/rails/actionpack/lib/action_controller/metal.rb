require 'active_support/core_ext/array/extract_options'
require 'action_dispatch/middleware/stack'

module ActionController
  class MiddlewareStack < ActionDispatch::MiddlewareStack #:nodoc:
    class Middleware < ActionDispatch::MiddlewareStack::Middleware #:nodoc:
      def initialize(klass, *args, &block)
        options = args.extract_options!
        @only   = Array(options.delete(:only)).map(&:to_s)
        @except = Array(options.delete(:except)).map(&:to_s)
        args << options unless options.empty?
        super
      end

      def valid?(action)
        if @only.present?
          @only.include?(action)
        elsif @except.present?
          !@except.include?(action)
        else
          true
        end
      end
    end

    def build(action, app = Proc.new)
      action = action.to_s

      middlewares.reverse.inject(app) do |a, middleware|
        middleware.valid?(action) ? middleware.build(a) : a
      end
    end
  end

  class Metal < AbstractController::Base
    abstract!

    attr_internal_writer :env

    def env
      @_env ||= {}
    end

    def self.controller_name
      @controller_name ||= name.demodulize.sub(/Controller$/, '').underscore
    end

    def controller_name
      self.class.controller_name
    end


    attr_internal :headers, :response, :request
    delegate :session, :to => "@_request"

    def initialize
      @_headers = {"Content-Type" => "text/html"}
      @_status = 200
      @_request = nil
      @_response = nil
      @_routes = nil
      super
    end

    def params
      @_params ||= request.parameters
    end

    def params=(val)
      @_params = val
    end


    def content_type=(type)
      headers["Content-Type"] = type.to_s
    end

    def content_type
      headers["Content-Type"]
    end

    def location
      headers["Location"]
    end

    def location=(url)
      headers["Location"] = url
    end

    def url_for(string)
      string
    end

    def status
      @_status
    end
    alias :response_code :status # :nodoc:

    def status=(status)
      @_status = Rack::Utils.status_code(status)
    end

    def response_body=(body)
      body = [body] unless body.nil? || body.respond_to?(:each)
      super
    end

    def performed?
      response_body || (response && response.committed?)
    end

    def dispatch(name, request) #:nodoc:
      @_request = request
      @_env = request.env
      @_env['action_controller.instance'] = self
      process(name)
      to_a
    end

    def to_a #:nodoc:
      response ? response.to_a : [status, headers, response_body]
    end

    class_attribute :middleware_stack
    self.middleware_stack = ActionController::MiddlewareStack.new

    def self.inherited(base) # :nodoc:
      base.middleware_stack = middleware_stack.dup
      super
    end

    def self.use(*args, &block)
      middleware_stack.use(*args, &block)
    end

    def self.middleware
      middleware_stack
    end

    def self.call(env)
      req = ActionDispatch::Request.new env
      action(req.path_parameters[:action]).call(env)
    end

    def self.action(name, klass = ActionDispatch::Request)
      if middleware_stack.any?
        middleware_stack.build(name) do |env|
          new.dispatch(name, klass.new(env))
        end
      else
        lambda { |env| new.dispatch(name, klass.new(env)) }
      end
    end
  end
end
