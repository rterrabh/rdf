if Rails.configuration.respond_to?(:load_mini_profiler) && Rails.configuration.load_mini_profiler
  require 'rack-mini-profiler'
  require 'flamegraph'

  begin
    require 'memory_profiler' if RUBY_VERSION >= "2.1.0"
  rescue => e
     STDERR.put "#{e} failed to require mini profiler"
  end

  Rack::MiniProfilerRails.initialize!(Rails.application)
end

if defined?(Rack::MiniProfiler)

  Rack::MiniProfiler.config.storage_instance = Rack::MiniProfiler::RedisStore.new(connection:  DiscourseRedis.raw_connection)

  skip = [
    /^\/message-bus/,
    /topics\/timings/,
    /assets/,
    /\/user_avatar\//,
    /\/letter_avatar\//,
    /\/highlight-js\//,
    /qunit/,
    /srv\/status/,
    /commits-widget/,
    /^\/cdn_asset/,
    /^\/logs/,
    /^\/site_customizations/,
    /^\/uploads/,
    /^\/javascripts\//,
    /^\/images\//,
    /^\/stylesheets\//,
    /^\/favicon\/proxied/
  ]

  Rack::MiniProfiler.config.pre_authorize_cb = lambda do |env|
    path = env['PATH_INFO']

    (env['HTTP_USER_AGENT'] !~ /iPad|iPhone|Nexus 7|Android/) &&
    !skip.any?{|re| re =~ path}
  end

  Rack::MiniProfiler.config.user_provider = lambda do |env|
    request = Rack::Request.new(env)
    id = request.cookies["_t"] || request.ip || "unknown"
    id = id.to_s
    Digest::MD5.hexdigest(id)
  end

  Rack::MiniProfiler.config.position = 'left'
  Rack::MiniProfiler.config.backtrace_ignores ||= []
  Rack::MiniProfiler.config.backtrace_ignores << /lib\/rack\/message_bus.rb/
  Rack::MiniProfiler.config.backtrace_ignores << /config\/initializers\/silence_logger/
  Rack::MiniProfiler.config.backtrace_ignores << /config\/initializers\/quiet_logger/





end


if ENV["PRINT_EXCEPTIONS"]
  trace      = TracePoint.new(:raise) do |tp|
    puts tp.raised_exception
    puts tp.raised_exception.backtrace.join("\n")
    puts
  end
  trace.enable
end
