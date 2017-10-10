
if AppConfig.environment.require_ssl?
  Rails.application.config.middleware.insert_before 0, Rack::SSL
  puts "Rack::SSL is enabled"
end
