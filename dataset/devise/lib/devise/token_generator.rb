require 'thread_safe'
require 'openssl'
require 'securerandom'

module Devise
  class TokenGenerator
    def initialize(key_generator, digest="SHA256")
      @key_generator = key_generator
      @digest = digest
    end

    def digest(klass, column, value)
      value.present? && OpenSSL::HMAC.hexdigest(@digest, key_for(column), value.to_s)
    end

    def generate(klass, column)
      key = key_for(column)

      loop do
        raw = Devise.friendly_token
        enc = OpenSSL::HMAC.hexdigest(@digest, key, raw)
        break [raw, enc] unless klass.to_adapter.find_first({ column => enc })
      end
    end

    private

    def key_for(column)
      @key_generator.generate_key("Devise #{column}")
    end
  end

  class KeyGenerator
    def initialize(secret, options = {})
      @secret = secret
      @iterations = options[:iterations] || 2**16
    end

    def generate_key(salt, key_size=64)
      OpenSSL::PKCS5.pbkdf2_hmac_sha1(@secret, salt, @iterations, key_size)
    end
  end

  class CachingKeyGenerator
    def initialize(key_generator)
      @key_generator = key_generator
      @cache_keys = ThreadSafe::Cache.new
    end

    def generate_key(salt, key_size=64)
      @cache_keys["#{salt}#{key_size}"] ||= @key_generator.generate_key(salt, key_size)
    end
  end
end
