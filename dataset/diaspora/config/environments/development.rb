Diaspora::Application.configure do

  config.cache_classes = false

  config.eager_load = false

  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

  config.action_mailer.raise_delivery_errors = false

  config.active_record.migration_error = :page_load

  config.active_support.deprecation = :log

  config.action_dispatch.best_standards_support = :builtin


  config.assets.compress = false

  config.assets.debug = true

  config.log_to = %w[stdout file]

  config.show_log_configuration = true
end
