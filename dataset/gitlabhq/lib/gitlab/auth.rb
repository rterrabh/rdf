module Gitlab
  class Auth
    def find(login, password)
      user = User.by_login(login)

      if user.nil? || user.ldap_user?
        return nil unless Gitlab::LDAP::Config.enabled?

        Gitlab::LDAP::Authentication.login(login, password)
      else
        user if user.valid_password?(password)
      end
    end
  end
end
