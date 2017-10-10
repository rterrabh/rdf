module Spree
  module Frontend
    class Engine < ::Rails::Engine
      config.middleware.use "Spree::Frontend::Middleware::SeoAssist"

      initializer "spree.assets.precompile", group: :all do |app|
        app.config.assets.precompile += %w[
          spree/frontend/all*
          jquery.validate/localization/messages_*
        ]
      end

      initializer "spree.frontend.environment", before: :load_config_initializers do |app|
        Spree::Frontend::Config = Spree::FrontendConfiguration.new
      end
    end
  end
end
