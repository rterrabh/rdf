if Rails.env != 'development' || ENV['TRACK_REQUESTS']
  require 'middleware/request_tracker'
  Rails.configuration.middleware.unshift Middleware::RequestTracker
end
