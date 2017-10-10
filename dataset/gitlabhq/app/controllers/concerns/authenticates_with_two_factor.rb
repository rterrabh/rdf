module AuthenticatesWithTwoFactor
  extend ActiveSupport::Concern

  included do
    skip_before_action :require_no_authentication, only: [:create]
  end

  def prompt_for_two_factor(user)
    session[:otp_user_id] = user.id

    render 'devise/sessions/two_factor' and return
  end
end
