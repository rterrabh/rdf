require 'devise/strategies/base'

module Devise
  module Strategies
    class Authenticatable < Base
      attr_accessor :authentication_hash, :authentication_type, :password

      def store?
        super && !mapping.to.skip_session_storage.include?(authentication_type)
      end

      def valid?
        valid_for_params_auth? || valid_for_http_auth?
      end

      def clean_up_csrf?
        true
      end

    private

      def validate(resource, &block)
        result = resource && resource.valid_for_authentication?(&block)

        if result
          true
        else
          if resource
            fail!(resource.unauthenticated_message)
          end
          false
        end
      end

      def remember_me(resource)
        resource.remember_me = remember_me? if resource.respond_to?(:remember_me=)
      end

      def remember_me?
        valid_params? && Devise::TRUE_VALUES.include?(params_auth_hash[:remember_me])
      end

      def valid_for_http_auth?
        http_authenticatable? && request.authorization && with_authentication_hash(:http_auth, http_auth_hash)
      end

      def valid_for_params_auth?
        params_authenticatable? && valid_params_request? &&
          valid_params? && with_authentication_hash(:params_auth, params_auth_hash)
      end

      def http_authenticatable?
        mapping.to.http_authenticatable?(authenticatable_name)
      end

      def params_authenticatable?
        mapping.to.params_authenticatable?(authenticatable_name)
      end

      def params_auth_hash
        params[scope]
      end

      def http_auth_hash
        keys = [http_authentication_key, :password]
        Hash[*keys.zip(decode_credentials).flatten]
      end

      def valid_params_request?
        !!env["devise.allow_params_authentication"]
      end

      def valid_params?
        params_auth_hash.is_a?(Hash)
      end

      def valid_password?
        password.present?
      end

      def decode_credentials
        return [] unless request.authorization && request.authorization =~ /^Basic (.*)/m
        Base64.decode64($1).split(/:/, 2)
      end

      def with_authentication_hash(auth_type, auth_values)
        self.authentication_hash, self.authentication_type = {}, auth_type
        self.password = auth_values[:password]

        parse_authentication_key_values(auth_values, authentication_keys) &&
        parse_authentication_key_values(request_values, request_keys)
      end

      def authentication_keys
        @authentication_keys ||= mapping.to.authentication_keys
      end

      def http_authentication_key
        @http_authentication_key ||= mapping.to.http_authentication_key || case authentication_keys
          when Array then authentication_keys.first
          when Hash then authentication_keys.keys.first
        end
      end

      def request_keys
        @request_keys ||= mapping.to.request_keys
      end

      def request_values
        keys = request_keys.respond_to?(:keys) ? request_keys.keys : request_keys
        #nodyna <send-2786> <SD COMPLEX (array)>
        values = keys.map { |k| self.request.send(k) }
        Hash[keys.zip(values)]
      end

      def parse_authentication_key_values(hash, keys)
        keys.each do |key, enforce|
          value = hash[key].presence
          if value
            self.authentication_hash[key] = value
          else
            return false unless enforce == false
          end
        end
        true
      end

      def authenticatable_name
        @authenticatable_name ||=
          ActiveSupport::Inflector.underscore(self.class.name.split("::").last).
            sub("_authenticatable", "").to_sym
      end
    end
  end
end
