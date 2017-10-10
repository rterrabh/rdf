if Rails.env.production?
  Logster.store.ignore = [
    /^ActionController::RoutingError \(No route matches/,

    /^PG::Error: ERROR:\s+duplicate key/,

    /^ActionController::UnknownFormat/,

    /^AbstractController::ActionNotFound/,

    /^ActionDispatch::ParamsParser::ParseError/,

    /(?m).*?Line: (?:\D|0).*?Column: (?:\D|0)/,

    /^Script error\..*Line: 0/m,

    /^Can't verify CSRF token authenticity$/,

    /^ActiveRecord::RecordNotFound /,

    /^ActionController::BadRequest /
  ]
end

Logster.config.current_context = lambda{|env,&blk|
  begin
    if Rails.configuration.multisite
      request = Rack::Request.new(env)
      ActiveRecord::Base.connection_handler.clear_active_connections!
      RailsMultisite::ConnectionManagement.establish_connection(:host => request['__ws'] || request.host)
    end
    blk.call
  ensure
    ActiveRecord::Base.connection_handler.clear_active_connections!
  end
}

Logster.config.subdirectory = "#{GlobalSetting.relative_url_root}/logs"

Logster.config.application_version = Discourse.git_version
