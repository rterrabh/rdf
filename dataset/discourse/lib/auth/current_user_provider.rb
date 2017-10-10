module Auth; end
class Auth::CurrentUserProvider

  def initialize(env)
    raise NotImplementedError
  end

  def current_user
    raise NotImplementedError
  end

  def log_on_user(user,session,cookies)
    raise NotImplementedError
  end

  def is_api?
    raise NotImplementedError
  end

  def has_auth_cookie?
    raise NotImplementedError
  end


  def log_off_user(session, cookies)
    raise NotImplementedError
  end
end
