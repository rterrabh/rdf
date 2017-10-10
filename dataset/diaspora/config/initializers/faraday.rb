
unless Rails.env.test?
  require 'typhoeus/adapters/faraday'
  Faraday.default_adapter = :typhoeus
end

options = {
  request: {
    timeout: 25
  },
  ssl: {
    ca_file: AppConfig.environment.certificate_authorities.get
  }
}

Faraday.default_connection = Faraday::Connection.new(options) do |b|
  b.use FaradayMiddleware::FollowRedirects, limit: 8
  b.use :cookie_jar
  b.adapter Faraday.default_adapter
end
