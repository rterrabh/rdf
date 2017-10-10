require File.expand_path('../boot', __FILE__)
require 'rails/all'

require_relative '../lib/discourse_event'
require_relative '../lib/discourse_plugin'
require_relative '../lib/discourse_plugin_registry'

require_relative '../app/models/global_setting'

require 'pry-rails' if Rails.env.development?

if defined?(Bundler)
  Bundler.require(*Rails.groups(assets: %w(development test profile)))
end

module Discourse
  class Application < Rails::Application
    def config.database_configuration
      if Rails.env.production?
        GlobalSetting.database_config
      else
        super
      end
    end

    require 'discourse'
    require 'es6_module_transpiler/rails'
    require 'js_locale_helper'

    require 'highlight_js/highlight_js'

    if Rails.env.test? || Rails.env.development?
      require "mocha/version"
      require "mocha/deprecation"
      if Mocha::VERSION == "0.13.3" && Rails::VERSION::STRING == "3.2.12"
        Mocha::Deprecation.mode = :disabled
      end
    end

    config.assets.image_optim = false

    config.autoload_paths += Dir["#{config.root}/app/serializers"]
    config.autoload_paths += Dir["#{config.root}/lib/validators/"]
    config.autoload_paths += Dir["#{config.root}/app"]


    config.assets.paths += %W(#{config.root}/config/locales #{config.root}/public/javascripts)

    config.assets.skip_minification = []

    config.assets.precompile += [lambda do |filename, path|
      path =~ /assets\/images/ && !%w(.js .css).include?(File.extname(filename))
    end]

    config.assets.precompile += ['vendor.js', 'common.css', 'desktop.css', 'mobile.css', 'admin.js', 'admin.css', 'shiny/shiny.css', 'preload_store.js', 'browser-update.js', 'embed.css', 'break_string.js']

    Dir.glob("#{config.root}/app/assets/javascripts/defer/*.js").each do |file|
      config.assets.precompile << "defer/#{File.basename(file)}"
    end

    Dir.glob("#{config.root}/app/assets/javascripts/locales/*.js.erb").each do |file|
      config.assets.precompile << "locales/#{file.match(/([a-z_A-Z]+\.js)\.erb$/)[1]}"
    end

    config.active_record.observers = [
        :user_email_observer,
        :user_action_observer,
        :post_alert_observer,
        :search_observer
    ]

    config.time_zone = 'UTC'

    config.i18n.load_path += Dir["#{Rails.root}/plugins/*/config/locales/*.yml"]

    config.encoding = 'utf-8'

    config.filter_parameters += [
        :password,
        :pop3_polling_password,
        :s3_secret_access_key,
        :twitter_consumer_secret,
        :facebook_app_secret,
        :github_client_secret
    ]

    config.assets.enabled = true

    config.assets.version = '1.2.4'

    config.active_record.thread_safe!

    config.active_record.schema_format = :sql

    if Rails.version >= "4.2.0" && Rails.version < "5.0.0"
      config.active_record.raise_in_transactional_callbacks = false
    end

    config.pbkdf2_iterations = 64000
    config.pbkdf2_algorithm = "sha256"

    config.middleware.delete Rack::Lock

    config.middleware.delete Rack::ETag

    config.exceptions_app = self.routes

    config.handlebars.templates_root = 'discourse/templates'

    require 'discourse_redis'
    require 'logster/redis_store'
    config.cache_store = DiscourseRedis.new_redis_store
    $redis = DiscourseRedis.new
    Logster.store = Logster::RedisStore.new(DiscourseRedis.new)

    config.action_dispatch.rack_cache =  nil

    config.ember.variant = :development
    config.ember.ember_location = "#{Rails.root}/vendor/assets/javascripts/production/ember.js"
    config.ember.handlebars_location = "#{Rails.root}/vendor/assets/javascripts/handlebars.js"

    require 'auth'
    Discourse.activate_plugins! unless Rails.env.test? and ENV['LOAD_PLUGINS'] != "1"

    if GlobalSetting.relative_url_root.present?
      config.relative_url_root = GlobalSetting.relative_url_root
    end

    config.after_initialize do
      OpenID::Util.logger = Rails.logger
      if plugins = Discourse.plugins
        plugins.each{|plugin| plugin.notify_after_initialize}
      end
    end

    if ENV['RBTRACE'] == "1"
      require 'rbtrace'
    end

  end
end

if defined?(PhusionPassenger)
  PhusionPassenger.on_event(:starting_worker_process) do |forked|
    if forked
      Discourse.after_fork
    end
  end
end
