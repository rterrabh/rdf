Devise.setup do |config|
  config.warden do |manager|
    manager.default_strategies(scope: :user).unshift :two_factor_authenticatable
    manager.default_strategies(scope: :user).unshift :two_factor_backupable
  end

  config.mailer = "DeviseMailer"

  require 'devise/orm/active_record'

  config.authentication_keys = [ :login ]


  config.case_insensitive_keys = [ :email ]

  config.strip_whitespace_keys = [ :email ]





  config.reconfirmable = true


  config.stretches = Rails.env.test? ? 1 : 10








  config.password_length = 8..128



  config.lock_strategy = :failed_attempts


  config.unlock_strategy = :time

  config.maximum_attempts = 10

  config.unlock_in = 10.minutes


  config.reset_password_within = 2.days


  config.skip_session_storage << :token_auth





  config.sign_out_via = :delete



  if Gitlab::LDAP::Config.enabled?
    Gitlab.config.ldap.servers.values.each do |server|
      if server['allow_username_or_email_login']
        email_stripping_proc = ->(name) {name.gsub(/@.*\z/,'')}
      else
        email_stripping_proc = ->(name) {name}
      end

      config.omniauth server['provider_name'],
        host:     server['host'],
        base:     server['base'],
        uid:      server['uid'],
        port:     server['port'],
        method:   server['method'],
        bind_dn:  server['bind_dn'],
        password: server['password'],
        name_proc: email_stripping_proc
    end
  end

  Gitlab.config.omniauth.providers.each do |provider|
    provider_arguments = []

    %w[app_id app_secret].each do |argument|
      provider_arguments << provider[argument] if provider[argument]
    end

    case provider['args']
    when Array
      provider_arguments.concat provider['args']
    when Hash
      provider_arguments << provider['args']
    end

    config.omniauth provider['name'].to_sym, *provider_arguments
  end
end
