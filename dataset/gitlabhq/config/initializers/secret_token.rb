
require 'securerandom'


def find_secure_token
  token_file = Rails.root.join('.secret')
  if ENV.key?('SECRET_KEY_BASE')
    ENV['SECRET_KEY_BASE']
  elsif File.exist? token_file
    File.read(token_file).chomp
  else
    token = SecureRandom.hex(64)
    File.write(token_file, token)
    token
  end
end

Gitlab::Application.config.secret_token = find_secure_token
Gitlab::Application.config.secret_key_base = find_secure_token
