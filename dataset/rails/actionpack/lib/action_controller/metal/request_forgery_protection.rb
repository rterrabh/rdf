require 'rack/session/abstract/id'
require 'action_controller/metal/exceptions'
require 'active_support/security_utils'

module ActionController #:nodoc:
  class InvalidAuthenticityToken < ActionControllerError #:nodoc:
  end

  class InvalidCrossOriginRequest < ActionControllerError #:nodoc:
  end

  module RequestForgeryProtection
    extend ActiveSupport::Concern

    include AbstractController::Helpers
    include AbstractController::Callbacks

    included do
      config_accessor :request_forgery_protection_token
      self.request_forgery_protection_token ||= :authenticity_token

      config_accessor :forgery_protection_strategy
      self.forgery_protection_strategy = nil

      config_accessor :allow_forgery_protection
      self.allow_forgery_protection = true if allow_forgery_protection.nil?

      config_accessor :log_warning_on_csrf_failure
      self.log_warning_on_csrf_failure = true

      helper_method :form_authenticity_token
      helper_method :protect_against_forgery?
    end

    module ClassMethods
      def protect_from_forgery(options = {})
        self.forgery_protection_strategy = protection_method_class(options[:with] || :null_session)
        self.request_forgery_protection_token ||= :authenticity_token
        prepend_before_action :verify_authenticity_token, options
        append_after_action :verify_same_origin_request
      end

      private

      def protection_method_class(name)
        #nodyna <const_get-1303> <CG COMPLEX (change-prone variable)>
        ActionController::RequestForgeryProtection::ProtectionMethods.const_get(name.to_s.classify)
      rescue NameError
        raise ArgumentError, 'Invalid request forgery protection method, use :null_session, :exception, or :reset_session'
      end
    end

    module ProtectionMethods
      class NullSession
        def initialize(controller)
          @controller = controller
        end

        def handle_unverified_request
          request = @controller.request
          request.session = NullSessionHash.new(request.env)
          request.env['action_dispatch.request.flash_hash'] = nil
          request.env['rack.session.options'] = { skip: true }
          request.env['action_dispatch.cookies'] = NullCookieJar.build(request)
        end

        protected

        class NullSessionHash < Rack::Session::Abstract::SessionHash #:nodoc:
          def initialize(env)
            super(nil, env)
            @data = {}
            @loaded = true
          end

          def destroy; end

          def exists?
            true
          end
        end

        class NullCookieJar < ActionDispatch::Cookies::CookieJar #:nodoc:
          def self.build(request)
            key_generator = request.env[ActionDispatch::Cookies::GENERATOR_KEY]
            host          = request.host
            secure        = request.ssl?

            new(key_generator, host, secure, options_for_env({}))
          end

          def write(*)
          end
        end
      end

      class ResetSession
        def initialize(controller)
          @controller = controller
        end

        def handle_unverified_request
          @controller.reset_session
        end
      end

      class Exception
        def initialize(controller)
          @controller = controller
        end

        def handle_unverified_request
          raise ActionController::InvalidAuthenticityToken
        end
      end
    end

    protected
      def verify_authenticity_token
        mark_for_same_origin_verification!

        if !verified_request?
          if logger && log_warning_on_csrf_failure
            logger.warn "Can't verify CSRF token authenticity"
          end
          handle_unverified_request
        end
      end

      def handle_unverified_request
        forgery_protection_strategy.new(self).handle_unverified_request
      end

      CROSS_ORIGIN_JAVASCRIPT_WARNING = "Security warning: an embedded " \
        "<script> tag on another site requested protected JavaScript. " \
        "If you know what you're doing, go ahead and disable forgery " \
        "protection on this action to permit cross-origin JavaScript embedding."
      private_constant :CROSS_ORIGIN_JAVASCRIPT_WARNING

      def verify_same_origin_request
        if marked_for_same_origin_verification? && non_xhr_javascript_response?
          logger.warn CROSS_ORIGIN_JAVASCRIPT_WARNING if logger
          raise ActionController::InvalidCrossOriginRequest, CROSS_ORIGIN_JAVASCRIPT_WARNING
        end
      end

      def mark_for_same_origin_verification!
        @marked_for_same_origin_verification = request.get?
      end

      def marked_for_same_origin_verification?
        @marked_for_same_origin_verification ||= false
      end

      def non_xhr_javascript_response?
        content_type =~ %r(\Atext/javascript) && !request.xhr?
      end

      AUTHENTICITY_TOKEN_LENGTH = 32

      def verified_request?
        !protect_against_forgery? || request.get? || request.head? ||
          valid_authenticity_token?(session, form_authenticity_param) ||
          valid_authenticity_token?(session, request.headers['X-CSRF-Token'])
      end

      def form_authenticity_token
        masked_authenticity_token(session)
      end

      def masked_authenticity_token(session)
        one_time_pad = SecureRandom.random_bytes(AUTHENTICITY_TOKEN_LENGTH)
        encrypted_csrf_token = xor_byte_strings(one_time_pad, real_csrf_token(session))
        masked_token = one_time_pad + encrypted_csrf_token
        Base64.strict_encode64(masked_token)
      end

      def valid_authenticity_token?(session, encoded_masked_token)
        if encoded_masked_token.nil? || encoded_masked_token.empty? || !encoded_masked_token.is_a?(String)
          return false
        end

        begin
          masked_token = Base64.strict_decode64(encoded_masked_token)
        rescue ArgumentError # encoded_masked_token is invalid Base64
          return false
        end


        if masked_token.length == AUTHENTICITY_TOKEN_LENGTH
          compare_with_real_token masked_token, session

        elsif masked_token.length == AUTHENTICITY_TOKEN_LENGTH * 2
          one_time_pad = masked_token[0...AUTHENTICITY_TOKEN_LENGTH]
          encrypted_csrf_token = masked_token[AUTHENTICITY_TOKEN_LENGTH..-1]
          csrf_token = xor_byte_strings(one_time_pad, encrypted_csrf_token)

          compare_with_real_token csrf_token, session

        else
          false # Token is malformed
        end
      end

      def compare_with_real_token(token, session)
        ActiveSupport::SecurityUtils.secure_compare(token, real_csrf_token(session))
      end

      def real_csrf_token(session)
        session[:_csrf_token] ||= SecureRandom.base64(AUTHENTICITY_TOKEN_LENGTH)
        Base64.strict_decode64(session[:_csrf_token])
      end

      def xor_byte_strings(s1, s2)
        s1.bytes.zip(s2.bytes).map { |(c1,c2)| c1 ^ c2 }.pack('c*')
      end

      def form_authenticity_param
        params[request_forgery_protection_token]
      end

      def protect_against_forgery?
        allow_forgery_protection
      end
  end
end
