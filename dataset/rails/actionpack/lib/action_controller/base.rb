require 'action_view'
require "action_controller/log_subscriber"
require "action_controller/metal/params_wrapper"

module ActionController
  class Base < Metal
    abstract!




    def self.without_modules(*modules)
      modules = modules.map do |m|
        #nodyna <const_get-1294> <CG COMPLEX (array)>
        m.is_a?(Symbol) ? ActionController.const_get(m) : m
      end

      MODULES - modules
    end

    MODULES = [
      AbstractController::Rendering,
      AbstractController::Translation,
      AbstractController::AssetPaths,

      Helpers,
      HideActions,
      UrlFor,
      Redirecting,
      ActionView::Layouts,
      Rendering,
      Renderers::All,
      ConditionalGet,
      EtagWithTemplateDigest,
      RackDelegation,
      Caching,
      MimeResponds,
      ImplicitRender,
      StrongParameters,

      Cookies,
      Flash,
      RequestForgeryProtection,
      ForceSSL,
      Streaming,
      DataStreaming,
      HttpAuthentication::Basic::ControllerMethods,
      HttpAuthentication::Digest::ControllerMethods,
      HttpAuthentication::Token::ControllerMethods,

      AbstractController::Callbacks,

      Rescue,

      Instrumentation,

      ParamsWrapper
    ]

    MODULES.each do |mod|
      include mod
    end

    PROTECTED_IVARS = AbstractController::Rendering::DEFAULT_PROTECTED_INSTANCE_VARIABLES + [
      :@_status, :@_headers, :@_params, :@_env, :@_response, :@_request,
      :@_view_runtime, :@_stream, :@_url_options, :@_action_has_layout ]

    def _protected_ivars # :nodoc:
      PROTECTED_IVARS
    end

    def self.protected_instance_variables
      PROTECTED_IVARS
    end

    ActiveSupport.run_load_hooks(:action_controller, self)
  end
end
