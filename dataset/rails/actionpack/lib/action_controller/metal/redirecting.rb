module ActionController
  class RedirectBackError < AbstractController::Error #:nodoc:
    DEFAULT_MESSAGE = 'No HTTP_REFERER was set in the request to this action, so redirect_to :back could not be called successfully. If this is a test, make sure to specify request.env["HTTP_REFERER"].'

    def initialize(message = nil)
      super(message || DEFAULT_MESSAGE)
    end
  end

  module Redirecting
    extend ActiveSupport::Concern

    include AbstractController::Logger
    include ActionController::RackDelegation
    include ActionController::UrlFor

    def redirect_to(options = {}, response_status = {}) #:doc:
      raise ActionControllerError.new("Cannot redirect to nil!") unless options
      raise ActionControllerError.new("Cannot redirect to a parameter hash!") if options.is_a?(ActionController::Parameters)
      raise AbstractController::DoubleRenderError if response_body

      self.status        = _extract_redirect_to_status(options, response_status)
      self.location      = _compute_redirect_to_location(request, options)
      self.response_body = "<html><body>You are being <a href=\"#{ERB::Util.unwrapped_html_escape(location)}\">redirected</a>.</body></html>"
    end

    def _compute_redirect_to_location(request, options) #:nodoc:
      case options
      when /\A([a-z][a-z\d\-+\.]*:|\/\/).*/i
        options
      when String
        request.protocol + request.host_with_port + options
      when :back
        request.headers["Referer"] or raise RedirectBackError
      when Proc
        _compute_redirect_to_location request, options.call
      else
        url_for(options)
      end.delete("\0\r\n")
    end
    module_function :_compute_redirect_to_location
    public :_compute_redirect_to_location

    private
      def _extract_redirect_to_status(options, response_status)
        if options.is_a?(Hash) && options.key?(:status)
          Rack::Utils.status_code(options.delete(:status))
        elsif response_status.key?(:status)
          Rack::Utils.status_code(response_status[:status])
        else
          302
        end
      end
  end
end
