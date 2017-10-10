Discourse::Application.configure do

  config.eager_load = true

  config.cache_classes = true

  config.log_level = :info

  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true

  config.serve_static_assets = true

  config.assets.compress = true

  config.assets.compile = true

  config.assets.digest = true

  config.action_dispatch.x_sendfile_header = 'X-Accel-Redirect' # for nginx

  config.action_mailer.smtp_settings = { address: "localhost", port: 1025 }

  config.active_support.deprecation = :notify

  config.handlebars.precompile = true

  config.load_mini_profiler = false

  config.after_initialize do
    Logster.logger = Rails.logger
  end

end
