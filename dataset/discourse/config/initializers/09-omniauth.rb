require "openssl"
require "openid_redis_store"


Rails.application.config.middleware.use OmniAuth::Builder do
  Discourse.authenticators.each do |authenticator|
    authenticator.register_middleware(self)
  end
end
