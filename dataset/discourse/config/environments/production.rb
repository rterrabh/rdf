Discourse::Application.configure do

  config.cache_classes = true
  config.eager_load = true

  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true

  config.serve_static_assets = GlobalSetting.serve_static_assets

  config.assets.js_compressor = :uglifier

  config.assets.css_compressor = :sass

  config.assets.compile = false

  config.assets.digest = true

  config.log_level = :info

  if GlobalSetting.smtp_address
    settings = {
      address:              GlobalSetting.smtp_address,
      port:                 GlobalSetting.smtp_port,
      domain:               GlobalSetting.smtp_domain,
      user_name:            GlobalSetting.smtp_user_name,
      password:             GlobalSetting.smtp_password,
      authentication:       GlobalSetting.smtp_authentication,
      enable_starttls_auto: GlobalSetting.smtp_enable_start_tls
    }

    settings[:openssl_verify_mode] = GlobalSetting.smtp_openssl_verify_mode if GlobalSetting.smtp_openssl_verify_mode

    config.action_mailer.smtp_settings = settings.reject{|_, y| y.nil?}
  else
    config.action_mailer.delivery_method = :sendmail
    config.action_mailer.sendmail_settings = {arguments: '-i'}
  end

  config.active_support.deprecation = :notify

  config.handlebars.precompile = true

  config.load_mini_profiler = GlobalSetting.load_mini_profiler

  config.action_controller.asset_host = GlobalSetting.cdn_url

  if emails = GlobalSetting.developer_emails
    config.developer_emails = emails.split(",").map(&:strip)
  end

end
