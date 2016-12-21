require 'gitlab/o_auth/user'

# LDAP extension for User model
#
# * Find or create user from omniauth.auth data
# * Links LDAP account with existing user
# * Auth LDAP user with login and password
#
module Gitlab
  module LDAP
    class User < Gitlab::OAuth::User
      class << self
        def find_by_uid_and_provider(uid, provider)
          # LDAP distinguished name is case-insensitive
          identity = ::Identity.
            where(provider: provider).
            where('lower(extern_uid) = ?', uid.downcase).last
          identity && identity.user
        end
      end

      def initialize(auth_hash)
        super
        update_user_attributes
      end

      # instance methods
      def gl_user
        @gl_user ||= find_by_uid_and_provider || find_by_email || build_new_user
      end

      def find_by_uid_and_provider
        self.class.find_by_uid_and_provider(
          auth_hash.uid.downcase, auth_hash.provider)
      end

      def find_by_email
        ::User.find_by(email: auth_hash.email)
      end

      def update_user_attributes
        return unless persisted?

        gl_user.skip_reconfirmation!
        gl_user.email = auth_hash.email

        # Build new identity only if we dont have have same one
        gl_user.identities.find_or_initialize_by(provider: auth_hash.provider,
                                                 extern_uid: auth_hash.uid)

        gl_user
      end

      def changed?
        gl_user.changed? || gl_user.identities.any?(&:changed?)
      end

      def block_after_signup?
        ldap_config.block_auto_created_users
      end

      def allowed?
        Gitlab::LDAP::Access.allowed?(gl_user)
      end

      def ldap_config
        Gitlab::LDAP::Config.new(auth_hash.provider)
      end
    end
  end
end
