Discourse::Application.configure do

  config.cache_classes = true

  config.serve_static_assets = true

  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

  config.action_dispatch.show_exceptions = false

  config.action_controller.allow_forgery_protection    = false

  config.action_mailer.delivery_method = :test


  config.active_support.deprecation = :stderr

  config.pbkdf2_iterations = 10
  config.ember.variant = :development

  config.assets.compile = true
  config.assets.digest = false

  config.eager_load = false
end
