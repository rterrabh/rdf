module Middleware

  class TurboDev
    def initialize(app, settings={})
      @app = app
    end

    def call(env)
      root = "#{GlobalSetting.relative_url_root}/assets/"
      is_asset = env['REQUEST_PATH'] && env['REQUEST_PATH'].starts_with?(root)

      if (etag = env['HTTP_IF_NONE_MATCH']) && is_asset
        name = env['REQUEST_PATH'][(root.length)..-1]
        etag = etag.gsub "\"", ""
        asset = Rails.application.assets.find_asset(name)
        if asset && asset.digest == etag
          return [304,{},[]]
        end
      end

      status, headers, response = @app.call(env)
      headers['Cache-Control'] = 'no-cache' if is_asset
      [status, headers, response]
    end
  end

end
