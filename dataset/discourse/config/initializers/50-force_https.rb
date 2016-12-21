# tiny middleware to force https if needed
class Discourse::ForceHttpsMiddleware

  def initialize(app, config={})
    @app = app
  end

  def call(env)
    env['rack.url_scheme'] = 'https' if SiteSetting.use_https
    @app.call(env)
  end

end

# this code plays up, skip for now
#Rails.configuration.middleware.insert_before MessageBus::Rack::Middleware, Discourse::ForceHttpsMiddleware

