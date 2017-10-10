app = Rails.application

if app.config.serve_static_assets

  app.config.middleware.swap(
    ActionDispatch::Static, 
    Gitlab::Middleware::Static, 
    app.paths["public"].first, 
    app.config.static_cache_control
  )
end
