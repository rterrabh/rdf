require File.expand_path('../boot', __FILE__)

require 'rails/all'
require 'devise'
I18n.config.enforce_available_locales = false
Bundler.require(:default, Rails.env)

module Gitlab
  class Application < Rails::Application

    config.autoload_paths.push(*%W(#{config.root}/lib


    config.i18n.enforce_available_locales = false

    config.encoding = "utf-8"

    config.filter_parameters.push(:password, :password_confirmation, :private_token, :otp_attempt)

    config.active_support.escape_html_entities_in_json = true


    config.assets.enabled = true
    config.assets.paths << Emoji.images_path
    config.assets.precompile << "emoji/*.png"
    config.assets.precompile << "print.css"

    config.assets.version = '1.0'

    config.action_view.sanitized_allowed_protocols = %w(smb)


    config.middleware.use Rack::Attack

    config.middleware.use Rack::Cors do
      allow do
        origins '*'
        resource '/api/*',
          headers: :any,
          methods: [:get, :post, :options, :put, :delete],
          expose: ['Link']
      end
    end

    redis_config_file = Rails.root.join('config', 'resque.yml')

    redis_url_string = if File.exists?(redis_config_file)
                         YAML.load_file(redis_config_file)[Rails.env]
                       else
                         "redis://localhost:6379"
                       end

    redis_config_hash = Redis::Store::Factory.extract_host_options_from_uri(redis_url_string)
    redis_uri = URI.parse(redis_url_string)
    if redis_uri.scheme == 'unix'
      redis_config_hash[:path] = redis_uri.path
    end

    redis_config_hash[:namespace] = 'cache:gitlab'
    redis_config_hash[:expires_in] = 2.weeks # Cache should not grow forever
    config.cache_store = :redis_store, redis_config_hash

    ENV['GITLAB_PATH_OUTSIDE_HOOK'] = ENV['PATH']
  end
end
