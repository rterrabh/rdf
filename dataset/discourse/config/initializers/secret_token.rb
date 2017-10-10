token = ENV['SECRET_TOKEN']
unless token
  token = $redis.get('SECRET_TOKEN')
  unless token && token.length == 128
    token = SecureRandom.hex(64)
    $redis.set('SECRET_TOKEN',token)
  end
end

Discourse::Application.config.secret_token = token
Discourse::Application.config.secret_key_base = token
