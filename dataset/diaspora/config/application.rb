require_relative 'boot'

require 'rails/all'
Bundler.require(:default, Rails.env)

require 'active_record/connection_adapters/abstract_mysql_adapter'
module ActiveRecord
  module ConnectionAdapters
    class Mysql2Adapter < AbstractMysqlAdapter
      def prepare_column_options(column, *_)
        super.tap {|spec|
          spec.delete(:limit) if column.type == :boolean
        }
      end
    end
  end
end

require_relative 'asset_sync'

module Diaspora
  class Application < Rails::Application

    config.autoload_paths      += %W{#{config.root}/app}
    config.autoload_once_paths += %W{#{config.root}/lib}





    config.encoding = "utf-8"

    config.active_support.escape_html_entities_in_json = true


    config.assets.enabled = true

    config.assets.initialize_on_precompile = false

    config.assets.precompile += %w{
      aspect-contacts.js
      contact-list.js
      ie.js
      inbox.js
      jquery.js
      jquery_ujs.js
      jquery-textchange.js
      main.js
      jsxc.js
      mobile/mobile.js
      people.js
      publisher.js
      templates.js
      validation.js

      bootstrap.css
      bootstrap-complete.css
      bootstrap-responsive.css
      error_pages.css
      admin.css
      mobile/mobile.css
      rtl.css
      home.css

      facebox/*
    }

    config.assets.version = '1.0'

    config.generators do |g|
      g.template_engine :haml
      g.test_framework  :rspec
    end

    config.active_record.raise_in_transactional_callbacks = true

    config.action_mailer.default_url_options = {
      protocol: AppConfig.pod_uri.scheme,
      host:     AppConfig.pod_uri.authority
    }
    config.action_mailer.asset_host = AppConfig.pod_uri.to_s
  end
end
