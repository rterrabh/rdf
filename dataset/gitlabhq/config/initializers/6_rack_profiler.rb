if Rails.env.development?
  require 'rack-mini-profiler'

  Rack::MiniProfilerRails.initialize!(Rails.application)

  Rack::MiniProfiler.config.position = 'right'
  Rack::MiniProfiler.config.start_hidden = false
  Rack::MiniProfiler.config.skip_paths << '/teaspoon'
end
