
require 'rack/oauth2'

module APIGuard
  extend ActiveSupport::Concern

  included do |base|
    use Rack::OAuth2::Server::Resource::Bearer, 'The API' do |request|

      request.access_token
    end

    helpers HelperMethods

    install_error_responders(base)
  end

  module HelperMethods
    def doorkeeper_guard!(scopes: [])
      if (access_token = find_access_token).nil?
        raise TokenNotFoundError

      else
        case validate_access_token(access_token, scopes)
        when Oauth2::AccessTokenValidationService::INSUFFICIENT_SCOPE
          raise InsufficientScopeError.new(scopes)
        when Oauth2::AccessTokenValidationService::EXPIRED
          raise ExpiredError
        when Oauth2::AccessTokenValidationService::REVOKED
          raise RevokedError
        when Oauth2::AccessTokenValidationService::VALID
          @current_user = User.find(access_token.resource_owner_id)
        end
      end
    end

    def doorkeeper_guard(scopes: [])
      if access_token = find_access_token
        case validate_access_token(access_token, scopes)
        when Oauth2::AccessTokenValidationService::INSUFFICIENT_SCOPE
          raise InsufficientScopeError.new(scopes)

        when Oauth2::AccessTokenValidationService::EXPIRED
          raise ExpiredError

        when Oauth2::AccessTokenValidationService::REVOKED
          raise RevokedError

        when Oauth2::AccessTokenValidationService::VALID
          @current_user = User.find(access_token.resource_owner_id)
        end
      end
    end

    def current_user
      @current_user
    end

    private
    def find_access_token
      @access_token ||= Doorkeeper.authenticate(doorkeeper_request, Doorkeeper.configuration.access_token_methods)
    end

    def doorkeeper_request
      @doorkeeper_request ||= ActionDispatch::Request.new(env)
    end

    def validate_access_token(access_token, scopes)
      Oauth2::AccessTokenValidationService.validate(access_token, scopes: scopes)
    end
  end

  module ClassMethods
    def guard_all!(scopes: [])
      before do
        guard! scopes: scopes
      end
    end

    private
    def install_error_responders(base)
      error_classes = [ MissingTokenError, TokenNotFoundError,
                        ExpiredError, RevokedError, InsufficientScopeError]

      #nodyna <send-495> <SD EASY (private methods)>
      base.send :rescue_from, *error_classes, oauth2_bearer_token_error_handler
    end

    def oauth2_bearer_token_error_handler
      Proc.new do |e|
        response =
          case e
          when MissingTokenError
            Rack::OAuth2::Server::Resource::Bearer::Unauthorized.new

          when TokenNotFoundError
            Rack::OAuth2::Server::Resource::Bearer::Unauthorized.new(
              :invalid_token,
              "Bad Access Token.")

          when ExpiredError
            Rack::OAuth2::Server::Resource::Bearer::Unauthorized.new(
              :invalid_token,
              "Token is expired. You can either do re-authorization or token refresh.")

          when RevokedError
            Rack::OAuth2::Server::Resource::Bearer::Unauthorized.new(
              :invalid_token,
              "Token was revoked. You have to re-authorize from the user.")

          when InsufficientScopeError
            Rack::OAuth2::Server::Resource::Bearer::Forbidden.new(
              :insufficient_scope,
              Rack::OAuth2::Server::Resource::ErrorMethods::DEFAULT_DESCRIPTION[:insufficient_scope],
              { scope: e.scopes })
          end

        response.finish
      end
    end
  end


  class MissingTokenError < StandardError; end

  class TokenNotFoundError < StandardError; end

  class ExpiredError < StandardError; end

  class RevokedError < StandardError; end

  class InsufficientScopeError < StandardError
    attr_reader :scopes
    def initialize(scopes)
      @scopes = scopes
    end
  end
end
