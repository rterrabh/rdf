unless Rails.env.test?
  Rack::Attack.blacklist('Git HTTP Basic Auth') do |req|
    Rack::Attack::Allow2Ban.filter(req.ip, Gitlab.config.rack_attack.git_basic_auth) do
      false
    end
  end
end
