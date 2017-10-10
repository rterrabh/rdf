require 'base64'

module ActionController
  module HttpAuthentication
    module Basic
      extend self

      module ControllerMethods
        extend ActiveSupport::Concern

        module ClassMethods
          def http_basic_authenticate_with(options = {})
            before_action(options.except(:name, :password, :realm)) do
              authenticate_or_request_with_http_basic(options[:realm] || "Application") do |name, password|
                name == options[:name] && password == options[:password]
              end
            end
          end
        end

        def authenticate_or_request_with_http_basic(realm = "Application", &login_procedure)
          authenticate_with_http_basic(&login_procedure) || request_http_basic_authentication(realm)
        end

        def authenticate_with_http_basic(&login_procedure)
          HttpAuthentication::Basic.authenticate(request, &login_procedure)
        end

        def request_http_basic_authentication(realm = "Application")
          HttpAuthentication::Basic.authentication_request(self, realm)
        end
      end

      def authenticate(request, &login_procedure)
        if has_basic_credentials?(request)
          login_procedure.call(*user_name_and_password(request))
        end
      end

      def has_basic_credentials?(request)
        request.authorization.present? && (auth_scheme(request) == 'Basic')
      end

      def user_name_and_password(request)
        decode_credentials(request).split(':', 2)
      end

      def decode_credentials(request)
        ::Base64.decode64(auth_param(request) || '')
      end

      def auth_scheme(request)
        request.authorization.split(' ', 2).first
      end

      def auth_param(request)
        request.authorization.split(' ', 2).second
      end

      def encode_credentials(user_name, password)
        "Basic #{::Base64.strict_encode64("#{user_name}:#{password}")}"
      end

      def authentication_request(controller, realm)
        controller.headers["WWW-Authenticate"] = %(Basic realm="#{realm.gsub(/"/, "")}")
        controller.status = 401
        controller.response_body = "HTTP Basic: Access denied.\n"
      end
    end

    module Digest
      extend self

      module ControllerMethods
        def authenticate_or_request_with_http_digest(realm = "Application", &password_procedure)
          authenticate_with_http_digest(realm, &password_procedure) || request_http_digest_authentication(realm)
        end

        def authenticate_with_http_digest(realm = "Application", &password_procedure)
          HttpAuthentication::Digest.authenticate(request, realm, &password_procedure)
        end

        def request_http_digest_authentication(realm = "Application", message = nil)
          HttpAuthentication::Digest.authentication_request(self, realm, message)
        end
      end

      def authenticate(request, realm, &password_procedure)
        request.authorization && validate_digest_response(request, realm, &password_procedure)
      end

      def validate_digest_response(request, realm, &password_procedure)
        secret_key  = secret_token(request)
        credentials = decode_credentials_header(request)
        valid_nonce = validate_nonce(secret_key, request, credentials[:nonce])

        if valid_nonce && realm == credentials[:realm] && opaque(secret_key) == credentials[:opaque]
          password = password_procedure.call(credentials[:username])
          return false unless password

          method = request.env['rack.methodoverride.original_method'] || request.env['REQUEST_METHOD']
          uri    = credentials[:uri]

          [true, false].any? do |trailing_question_mark|
            [true, false].any? do |password_is_ha1|
              _uri = trailing_question_mark ? uri + "?" : uri
              expected = expected_response(method, _uri, credentials, password, password_is_ha1)
              expected == credentials[:response]
            end
          end
        end
      end

      def expected_response(http_method, uri, credentials, password, password_is_ha1=true)
        ha1 = password_is_ha1 ? password : ha1(credentials, password)
        ha2 = ::Digest::MD5.hexdigest([http_method.to_s.upcase, uri].join(':'))
        ::Digest::MD5.hexdigest([ha1, credentials[:nonce], credentials[:nc], credentials[:cnonce], credentials[:qop], ha2].join(':'))
      end

      def ha1(credentials, password)
        ::Digest::MD5.hexdigest([credentials[:username], credentials[:realm], password].join(':'))
      end

      def encode_credentials(http_method, credentials, password, password_is_ha1)
        credentials[:response] = expected_response(http_method, credentials[:uri], credentials, password, password_is_ha1)
        "Digest " + credentials.sort_by {|x| x[0].to_s }.map {|v| "#{v[0]}='#{v[1]}'" }.join(', ')
      end

      def decode_credentials_header(request)
        decode_credentials(request.authorization)
      end

      def decode_credentials(header)
        ActiveSupport::HashWithIndifferentAccess[header.to_s.gsub(/^Digest\s+/, '').split(',').map do |pair|
          key, value = pair.split('=', 2)
          [key.strip, value.to_s.gsub(/^"|"$/,'').delete('\'')]
        end]
      end

      def authentication_header(controller, realm)
        secret_key = secret_token(controller.request)
        nonce = self.nonce(secret_key)
        opaque = opaque(secret_key)
        controller.headers["WWW-Authenticate"] = %(Digest realm="#{realm}", qop="auth", algorithm=MD5, nonce="#{nonce}", opaque="#{opaque}")
      end

      def authentication_request(controller, realm, message = nil)
        message ||= "HTTP Digest: Access denied.\n"
        authentication_header(controller, realm)
        controller.status = 401
        controller.response_body = message
      end

      def secret_token(request)
        key_generator  = request.env["action_dispatch.key_generator"]
        http_auth_salt = request.env["action_dispatch.http_auth_salt"]
        key_generator.generate_key(http_auth_salt)
      end

      def nonce(secret_key, time = Time.now)
        t = time.to_i
        hashed = [t, secret_key]
        digest = ::Digest::MD5.hexdigest(hashed.join(":"))
        ::Base64.strict_encode64("#{t}:#{digest}")
      end

      def validate_nonce(secret_key, request, value, seconds_to_timeout=5*60)
        return false if value.nil?
        t = ::Base64.decode64(value).split(":").first.to_i
        nonce(secret_key, t) == value && (t - Time.now.to_i).abs <= seconds_to_timeout
      end

      def opaque(secret_key)
        ::Digest::MD5.hexdigest(secret_key)
      end

    end

    module Token
      TOKEN_KEY = 'token='
      TOKEN_REGEX = /^Token /
      AUTHN_PAIR_DELIMITERS = /(?:,|;|\t+)/
      extend self

      module ControllerMethods
        def authenticate_or_request_with_http_token(realm = "Application", &login_procedure)
          authenticate_with_http_token(&login_procedure) || request_http_token_authentication(realm)
        end

        def authenticate_with_http_token(&login_procedure)
          Token.authenticate(self, &login_procedure)
        end

        def request_http_token_authentication(realm = "Application")
          Token.authentication_request(self, realm)
        end
      end


      def authenticate(controller, &login_procedure)
        token, options = token_and_options(controller.request)
        unless token.blank?
          login_procedure.call(token, options)
        end
      end

      def token_and_options(request)
        authorization_request = request.authorization.to_s
        if authorization_request[TOKEN_REGEX]
          params = token_params_from authorization_request
          [params.shift[1], Hash[params].with_indifferent_access]
        end
      end

      def token_params_from(auth)
        rewrite_param_values params_array_from raw_params auth
      end

      def params_array_from(raw_params)
        raw_params.map { |param| param.split %r/=(.+)?/ }
      end

      def rewrite_param_values(array_params)
        array_params.each { |param| (param[1] || "").gsub! %r/^"|"$/, '' }
      end

      def raw_params(auth)
        _raw_params = auth.sub(TOKEN_REGEX, '').split(/\s*#{AUTHN_PAIR_DELIMITERS}\s*/)

        if !(_raw_params.first =~ %r{\A#{TOKEN_KEY}})
          _raw_params[0] = "#{TOKEN_KEY}#{_raw_params.first}"
        end

        _raw_params
      end

      def encode_credentials(token, options = {})
        values = ["#{TOKEN_KEY}#{token.to_s.inspect}"] + options.map do |key, value|
          "#{key}=#{value.to_s.inspect}"
        end
        "Token #{values * ", "}"
      end

      def authentication_request(controller, realm)
        controller.headers["WWW-Authenticate"] = %(Token realm="#{realm.gsub(/"/, "")}")
        controller.__send__ :render, :text => "HTTP Token: Access denied.\n", :status => :unauthorized
      end
    end
  end
end
