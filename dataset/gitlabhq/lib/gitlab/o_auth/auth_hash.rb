# Class to parse and transform the info provided by omniauth
#
module Gitlab
  module OAuth
    class AuthHash
      attr_reader :auth_hash
      def initialize(auth_hash)
        @auth_hash = auth_hash
      end

      def uid
        @uid ||= Gitlab::Utils.force_utf8(auth_hash.uid.to_s)
      end

      def provider
        @provider ||= Gitlab::Utils.force_utf8(auth_hash.provider.to_s)
      end

      def info
        auth_hash.info
      end

      def get_info(key)
        value = info.try(key)
        Gitlab::Utils.force_utf8(value) if value
        value
      end

      def name
        @name ||= get_info(:name) || "#{get_info(:first_name)} #{get_info(:last_name)}"
      end

      def username
        @username ||= username_and_email[:username].to_s
      end

      def email
        @email ||= username_and_email[:email].to_s
      end

      def password
        @password ||= Gitlab::Utils.force_utf8(Devise.friendly_token[0, 8].downcase)
      end

      private

      def username_and_email
        @username_and_email ||= begin
          username  = get_info(:nickname) || get_info(:username)
          email     = get_info(:email)

          username ||= generate_username(email)             if email
          email    ||= generate_temporarily_email(username) if username

          {
            username: username,
            email:    email
          }
        end
      end

      # Get the first part of the email address (before @)
      # In addtion in removes illegal characters
      def generate_username(email)
        email.match(/^[^@]*/)[0].parameterize
      end

      def generate_temporarily_email(username)
        "temp-email-for-oauth-#{username}@gitlab.localhost"
      end
    end
  end
end
