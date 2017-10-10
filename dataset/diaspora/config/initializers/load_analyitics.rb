
if Rails.env == 'production'
  Diaspora::Application.configure do
    if AppConfig.privacy.google_analytics_key.present?
      require 'rack/google-analytics'
      config.middleware.use Rack::GoogleAnalytics, tracker: AppConfig.privacy.google_analytics_key.get
    end

    if AppConfig.privacy.piwik.enable?
      require 'rack/piwik'
      config.middleware.use Rack::Piwik, piwik_url: AppConfig.privacy.piwik.host.get,
                                         piwik_id:  AppConfig.privacy.piwik.site_id.get
    end
  end
end
