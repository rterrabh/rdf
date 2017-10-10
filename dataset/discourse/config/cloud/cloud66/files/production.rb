Discourse::Application.configure do

  config.cache_classes = true

  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true

  config.serve_static_assets = false

  config.assets.compress = true

  config.assets.compile = false

  config.assets.digest = true

  config.action_dispatch.x_sendfile_header = 'X-Accel-Redirect' # for nginx


  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
     :address              => ENV['SMTP_ADDRESS'],
     :port                 => ENV['SMTP_PORT'],
     :domain               => ENV['SMTP_DOMAIN'],
     :user_name            => ENV['SMTP_USERNAME'],
     :password             => ENV['SMTP_PASSWORD'],
     :authentication       => 'plain',
     :enable_starttls_auto => true  }


  config.active_support.deprecation = :notify

  config.handlebars.precompile = true

  config.enable_rack_cache = true

  config.load_mini_profiler = true



end
