Dummy::Application.configure do

  config.cache_classes = true

  config.serve_static_files = true
  config.static_cache_control = "public, max-age=3600"

  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

  config.eager_load = false

  config.action_dispatch.show_exceptions = false

  config.action_controller.allow_forgery_protection    = false

  config.action_mailer.delivery_method = :test
  ActionMailer::Base.default :from => "spree@example.com"

  config.active_support.deprecation = :stderr
end
