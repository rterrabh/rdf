
class Auth::Authenticator
  def after_authenticate(auth_options)
    raise NotImplementedError
  end

  def after_create_account(user, auth)
  end

  def register_middleware(omniauth)
    raise NotImplementedError
  end
end
