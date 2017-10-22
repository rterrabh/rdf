module Devise
  module TestHelpers
    def self.included(base)
      #nodyna <class_eval-2781> <CE MODERATE (block execution)>
      base.class_eval do
        setup :setup_controller_for_warden, :warden if respond_to?(:setup)
      end
    end

    def process(*)
      _catch_warden { super } || @response
    end

    def setup_controller_for_warden #:nodoc:
      @request.env['action_controller.instance'] = @controller
    end

    def warden #:nodoc:
      @warden ||= begin
        manager = Warden::Manager.new(nil) do |config|
          config.merge! Devise.warden_config
        end
        @request.env['warden'] = Warden::Proxy.new(@request.env, manager)
      end
    end

    def sign_in(resource_or_scope, resource=nil)
      scope    ||= Devise::Mapping.find_scope!(resource_or_scope)
      resource ||= resource_or_scope
      #nodyna <instance_variable_get-2782> <IVG EASY (private access)>
      warden.instance_variable_get(:@users).delete(scope)
      warden.session_serializer.store(resource, scope)
    end

    def sign_out(resource_or_scope)
      scope = Devise::Mapping.find_scope!(resource_or_scope)
      #nodyna <instance_variable_set-2783> <IVS COMPLEX (change-prone variable)>
      @controller.instance_variable_set(:"@current_#{scope}", nil)
      #nodyna <instance_variable_get-2784> <IVG EASY (private access)>
      user = warden.instance_variable_get(:@users).delete(scope)
      warden.session_serializer.delete(scope, user)
    end

    protected

    def _catch_warden(&block)
      result = catch(:warden, &block)

      env = @controller.request.env

      result ||= {}

      case result
      when Array
        if result.first == 401 && intercept_401?(env) # does this happen during testing?
          _process_unauthenticated(env)
        else
          result
        end
      when Hash
        _process_unauthenticated(env, result)
      else
        result
      end
    end

    def _process_unauthenticated(env, options = {})
      options[:action] ||= :unauthenticated
      proxy = env['warden']
      result = options[:result] || proxy.result

      ret = case result
      when :redirect
        body = proxy.message || "You are being redirected to #{proxy.headers['Location']}"
        [proxy.status, proxy.headers, [body]]
      when :custom
        proxy.custom_response
      else
        env["PATH_INFO"] = "/#{options[:action]}"
        env["warden.options"] = options
        Warden::Manager._run_callbacks(:before_failure, env, options)

        status, headers, response = Devise.warden_config[:failure_app].call(env).to_a
        @controller.response.headers.merge!(headers)
        #nodyna <send-2785> <SD TRIVIAL (public methods)>
        @controller.send :render, status: status, text: response.body,
          content_type: headers["Content-Type"], location: headers["Location"]
        nil # causes process return @response
      end

      if ret.is_a?(Array)
        @controller.response ||= @response
        @response.status = ret.first
        @response.headers = ret.second
        @response.body = ret.third
      end

      ret
    end
  end
end
