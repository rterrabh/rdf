Discourse.git_version

reload_settings = lambda {
  RailsMultisite::ConnectionManagement.each_connection do
    begin
      SiteSetting.refresh!
    rescue ActiveRecord::StatementInvalid
    rescue => e
      STDERR.puts "URGENT: #{e} Failed to initialize site #{RailsMultisite::ConnectionManagement.current_db}"
    end
  end
}

if Rails.configuration.cache_classes
  reload_settings.call
else
  ActionDispatch::Reloader.to_prepare do
    reload_settings.call
  end
end
