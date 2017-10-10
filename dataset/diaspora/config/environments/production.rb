Diaspora::Application.configure do

  config.cache_classes = true

  config.eager_load = true

  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true

  config.serve_static_files = false

  config.assets.js_compressor = :uglifier

  config.assets.compile = false

  config.assets.digest = true



  config.log_level = :info

  config.log_to = %w[file]

  config.show_log_configuration = false







  config.dependency_loading = true if $rails_rake_task

  config.i18n.fallbacks = true

  config.active_support.deprecation = :notify

  config.action_dispatch.x_sendfile_header = "X-Accel-Redirect"

  if AppConfig.environment.assets.host.present?
    config.action_controller.asset_host = AppConfig.environment.assets.host.get
  end
end
