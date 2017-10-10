require "action_controller/metal"

module Devise
  class FailureApp < ActionController::Metal
    include ActionController::RackDelegation
    include ActionController::UrlFor
    include ActionController::Redirecting

    include Rails.application.routes.url_helpers
    include Rails.application.routes.mounted_helpers

    include Devise::Controllers::StoreLocation

    delegate :flash, to: :request

    def self.call(env)
      @respond ||= action(:respond)
      @respond.call(env)
    end

    def self.default_url_options(*args)
      if defined?(ApplicationController)
        ApplicationController.default_url_options(*args)
      else
        {}
      end
    end

    def respond
      if http_auth?
        http_auth
      elsif warden_options[:recall]
        recall
      else
        redirect
      end
    end

    def http_auth
      self.status = 401
      self.headers["WWW-Authenticate"] = %(Basic realm=#{Devise.http_authentication_realm.inspect}) if http_auth_header?
      self.content_type = request.format.to_s
      self.response_body = http_auth_body
    end

    def recall
      env["PATH_INFO"]  = attempted_path
      flash.now[:alert] = i18n_message(:invalid)
      self.response = recall_app(warden_options[:recall]).call(env)
    end

    def redirect
      store_location!
      if flash[:timedout] && flash[:alert]
        flash.keep(:timedout)
        flash.keep(:alert)
      else
        flash[:alert] = i18n_message
      end
      redirect_to redirect_url
    end

  protected

    def i18n_options(options)
      options
    end

    def i18n_message(default = nil)
      message = warden_message || default || :unauthenticated

      if message.is_a?(Symbol)
        options = {}
        options[:resource_name] = scope
        options[:scope] = "devise.failure"
        options[:default] = [message]
        auth_keys = scope_class.authentication_keys
        keys = auth_keys.respond_to?(:keys) ? auth_keys.keys : auth_keys
        options[:authentication_keys] = keys.join(I18n.translate(:"support.array.words_connector"))
        options = i18n_options(options)

        I18n.t(:"#{scope}.#{message}", options)
      else
        message.to_s
      end
    end

    def redirect_url
      if warden_message == :timeout
        flash[:timedout] = true

        path = if request.get?
          attempted_path
        else
          request.referrer
        end

        path || scope_url
      else
        scope_url
      end
    end

    def scope_url
      opts  = {}
      route = :"new_#{scope}_session_url"
      opts[:format] = request_format unless skip_format?

      config = Rails.application.config
      opts[:script_name] = (config.relative_url_root if config.respond_to?(:relative_url_root))

      #nodyna <send-2756> <not yet classified>
      context = send(Devise.available_router_name)

      if context.respond_to?(route)
        #nodyna <send-2757> <not yet classified>
        context.send(route, opts)
      elsif respond_to?(:root_url)
        root_url(opts)
      else
        "/"
      end
    end

    def skip_format?
      %w(html */*).include? request_format.to_s
    end

    def http_auth?
      if request.xhr?
        Devise.http_authenticatable_on_xhr
      else
        !(request_format && is_navigational_format?)
      end
    end

    def http_auth_header?
      scope_class.http_authenticatable && !request.xhr?
    end

    def http_auth_body
      return i18n_message unless request_format
      method = "to_#{request_format}"
      if method == "to_xml"
        { error: i18n_message }.to_xml(root: "errors")
      elsif {}.respond_to?(method)
        #nodyna <send-2758> <not yet classified>
        { error: i18n_message }.send(method)
      else
        i18n_message
      end
    end

    def recall_app(app)
      controller, action = app.split("#")
      controller_name  = ActiveSupport::Inflector.camelize(controller)
      controller_klass = ActiveSupport::Inflector.constantize("#{controller_name}Controller")
      controller_klass.action(action)
    end

    def warden
      env['warden']
    end

    def warden_options
      env['warden.options']
    end

    def warden_message
      @message ||= warden.message || warden_options[:message]
    end

    def scope
      @scope ||= warden_options[:scope] || Devise.default_scope
    end

    def scope_class
      @scope_class ||= Devise.mappings[scope].to
    end

    def attempted_path
      warden_options[:attempted_path]
    end

    def store_location!
      store_location_for(scope, attempted_path) if request.get? && !http_auth?
    end

    def is_navigational_format?
      Devise.navigational_formats.include?(request_format)
    end

    def request_format
      @request_format ||= request.format.try(:ref)
    end
  end
end
