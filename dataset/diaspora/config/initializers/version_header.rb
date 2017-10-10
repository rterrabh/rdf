
ENV["RAILS_ASSET_ID"] = AppConfig.rails_asset_id if Rails.env.production? && ! AppConfig.heroku?
