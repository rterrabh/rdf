module Oauth2::AccessTokenValidationService
  VALID = :valid
  EXPIRED = :expired
  REVOKED = :revoked
  INSUFFICIENT_SCOPE = :insufficient_scope

  class << self
    def validate(token, scopes: [])
      if token.expired?
        return EXPIRED

      elsif token.revoked?
        return REVOKED

      elsif !self.sufficient_scope?(token, scopes)
        return INSUFFICIENT_SCOPE

      else
        return VALID
      end
    end

    protected
    def sufficient_scope?(token, scopes)
      if scopes.blank?
        return true
      else
        required_scopes = Set.new(scopes)
        authorized_scopes = Set.new(token.scopes)

        return authorized_scopes >= required_scopes
      end
    end
  end
end
