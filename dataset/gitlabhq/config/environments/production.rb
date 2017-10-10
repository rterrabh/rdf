Gitlab::Application.configure do

  config.cache_classes = true

  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true

  config.serve_static_assets = false

  config.assets.js_compressor = :uglifier

  config.assets.compile = true

  config.assets.digest = true





  %w{render_template render_partial render_collection}.each do |event|
    ActiveSupport::Notifications.unsubscribe "#{event}.action_view"
  end







  config.i18n.fallbacks = true

  config.active_support.deprecation = :notify

  config.action_mailer.delivery_method = :sendmail
  config.action_mailer.perform_deliveries = true
  config.action_mailer.raise_delivery_errors = true

  config.eager_load = true

  config.allow_concurrency = false
end
