Discourse::Application.configure do

  config.cache_classes = false

  config.eager_load = false

  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

  config.active_support.deprecation = :log

  config.assets.compress = false

  config.assets.digest = false

  config.assets.debug = false

  config.active_record.migration_error = :page_load
  config.watchable_dirs['lib'] = [:rb]

  config.sass.debug_info = false
  config.handlebars.precompile = false

  config.action_mailer.smtp_settings = { address: "localhost", port: 1025 }

  config.action_mailer.raise_delivery_errors = true

  BetterErrors::Middleware.allow_ip! ENV['TRUSTED_IP'] if ENV['TRUSTED_IP']

  config.load_mini_profiler = true

  require 'middleware/turbo_dev'
  config.middleware.insert 0, Middleware::TurboDev
  require 'middleware/missing_avatars'
  config.middleware.insert 1, Middleware::MissingAvatars

  config.enable_anon_caching = false
  require 'rbtrace'

  if emails = GlobalSetting.developer_emails
    config.developer_emails = emails.split(",").map(&:strip)
  end
end
