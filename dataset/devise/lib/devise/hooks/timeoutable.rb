Warden::Manager.after_set_user do |record, warden, options|
  scope = options[:scope]
  env   = warden.request.env

  if record && record.respond_to?(:timedout?) && warden.authenticated?(scope) && options[:store] != false
    last_request_at = warden.session(scope)['last_request_at']

    if last_request_at.is_a? Integer
      last_request_at = Time.at(last_request_at).utc
    elsif last_request_at.is_a? String
      last_request_at = Time.parse(last_request_at)
    end

    proxy = Devise::Hooks::Proxy.new(warden)

    if record.timedout?(last_request_at) && !env['devise.skip_timeout']
      Devise.sign_out_all_scopes ? proxy.sign_out : proxy.sign_out(scope)

      if record.respond_to?(:expire_auth_token_on_timeout) && record.expire_auth_token_on_timeout
        record.reset_authentication_token!
      end

      throw :warden, scope: scope, message: :timeout
    end

    unless env['devise.skip_trackable']
      warden.session(scope)['last_request_at'] = Time.now.utc.to_i
    end
  end
end