
Diaspora::Application.configure do
  config.serve_static_files = AppConfig.environment.assets.serve?
end
