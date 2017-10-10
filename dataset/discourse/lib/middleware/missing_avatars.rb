module Middleware

  class MissingAvatars
    def initialize(app, settings={})
      @app = app
    end

    def call(env)
      if (env['REQUEST_PATH'] =~ /^\/uploads\/default\/avatars/)
        path = "#{Rails.root}/public#{env['REQUEST_PATH']}"
        unless File.exist?(path) 
          default_image = "#{Rails.root}/public/images/d-logo-sketch-small.png"
          return [ 200, { 'Content-Type' => 'image/png' }, [ File.read(default_image)] ]
        end
      end
      
      status, headers, response = @app.call(env)
      [status, headers, response]
    end
  end

end
