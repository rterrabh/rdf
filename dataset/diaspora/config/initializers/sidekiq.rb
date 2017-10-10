require 'sidekiq_middlewares'
require 'sidekiq/middleware/i18n'

if AppConfig.environment.single_process_mode? && Rails.env != "test"
  if Rails.env == 'production'
    puts "WARNING: You are running Diaspora in production without Sidekiq"
    puts "         workers turned on.  Please set single_process_mode to false in"
    puts "         config/diaspora.yml."
  end
  require 'sidekiq/testing/inline'
end

Sidekiq.configure_server do |config|
  config.redis = AppConfig.get_redis_options

  config.server_middleware do |chain|
    chain.add SidekiqMiddlewares::CleanAndShortBacktraces
  end

  database_url = ENV['DATABASE_URL']
  if(database_url)
    ENV['DATABASE_URL'] = "#{database_url}?pool=#{AppConfig.environment.sidekiq.concurrency.get}"
    ActiveRecord::Base.establish_connection
  end

  UUID.generator.next_sequence

  class SidekiqLogger < SimpleDelegator
    SPACE = " "

    def info(data=nil)
      return false if Logger::Severity::INFO < level
      data = yield if data.nil? && block_given?
      __getobj__.info("#{context}#{data}")
    end

    def context
      c = Thread.current[:sidekiq_context]
      "#{c.join(SPACE)}: " if c && c.any?
    end
  end

  Sidekiq::Logging.logger = SidekiqLogger.new(Logging.logger[Sidekiq])
end

Sidekiq.configure_client do |config|
  config.redis = AppConfig.get_redis_options
end
