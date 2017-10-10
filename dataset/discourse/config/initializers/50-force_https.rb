class Discourse::ForceHttpsMiddleware

  def initialize(app, config={})
    @app = app
  end

  def call(env)
    env['rack.url_scheme'] = 'https' if SiteSetting.use_https
    @app.call(env)
  end

end


