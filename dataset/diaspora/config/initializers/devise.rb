
class ActionController::Responder
  def to_mobile
    default_render
  rescue ActionView::MissingTemplate => e
    navigation_behavior(e)
  end
end

Devise.setup do |config|
  config.secret_key = AppConfig.secret_token

  if AppConfig.mail.sender_address.present?
    config.mailer_sender = AppConfig.mail.sender_address
  elsif AppConfig.mail.enable?
    unless Rails.env == 'test'
      Rails.logger.warn("No smtp sender address set, mail may fail.")
      warn "WARNING: No smtp sender address set, mail may fail."
    end
    config.mailer_sender = "please-change-me@config-diaspora-yml.com"
  end

  config.mailer = "DiasporaDeviseMailer"

  require 'devise/orm/active_record'

  config.authentication_keys = [ :username ]


  config.case_insensitive_keys = %i(email unconfirmed_email username)

  config.strip_whitespace_keys = %i(email unconfirmed_email username)






  config.skip_session_storage = [:http_auth]


  config.stretches = Rails.env.test? ? 1 : 10

  config.pepper = "065eb8798b181ff0ea2c5c16aee0ff8b70e04e2ee6bd6e08b49da46924223e39127d5335e466207d42bf2a045c12be5f90e92012a4f05f7fc6d9f3c875f4c95b"



  config.reconfirmable = true


  config.remember_for = 2.weeks



  config.password_length = 6..128










  config.reset_password_within = 2.days



  config.default_scope = :user


  config.navigational_formats = ['*/*', :html, :mobile]

  config.sign_out_via = :delete



end
