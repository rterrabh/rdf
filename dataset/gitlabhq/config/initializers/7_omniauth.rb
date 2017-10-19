if Gitlab::LDAP::Config.enabled?
  module OmniAuth::Strategies
    server = Gitlab.config.ldap.servers.values.first
    klass = server['provider_class']
    #nodyna <const_set-547> <CS COMPLEX (change-prone variable)>
    const_set(klass, Class.new(LDAP)) unless klass == 'LDAP'
  end

  #nodyna <class_eval-548> <CE MODERATE (block execution)>
  OmniauthCallbacksController.class_eval do
    server = Gitlab.config.ldap.servers.values.first
    alias_method server['provider_name'], :ldap
  end
end

OmniAuth.config.full_host = Settings.gitlab['base_url']
OmniAuth.config.allowed_request_methods = [:post]
OmniAuth.config.allowed_request_methods << :get if Gitlab.config.omniauth.auto_sign_in_with_provider.present?
OmniAuth.config.before_request_phase do |env|
  OmniAuth::RequestForgeryProtection.new(env).call
end

if Gitlab.config.omniauth.enabled
  Gitlab.config.omniauth.providers.each do |provider|
    if provider['name'] == 'kerberos'
      require 'omniauth-kerberos'
    end
  end
end
