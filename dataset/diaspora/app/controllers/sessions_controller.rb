
class SessionsController < Devise::SessionsController
  after_filter :reset_authentication_token, :only => [:create]
  before_filter :reset_authentication_token, :only => [:destroy]

  def reset_authentication_token
    current_user.reset_authentication_token!
  end
end
