Devise.setup do |config|
<% if rails_4? -%>
<% else -%>
  config.secret_key = '<%= SecureRandom.hex(64) %>'
<% end -%>

  config.mailer_sender = 'please-change-me-at-config-initializers-devise@example.com'


  require 'devise/orm/<%= options[:orm] %>'



  config.case_insensitive_keys = [ :email ]

  config.strip_whitespace_keys = [ :email ]






  config.skip_session_storage = [:http_auth]


  config.stretches = Rails.env.test? ? 1 : 10




  config.reconfirmable = true



  config.expire_all_remember_me_on_sign_out = true



  config.password_length = 8..128











  config.reset_password_within = 6.hours






  config.sign_out_via = :delete



end
