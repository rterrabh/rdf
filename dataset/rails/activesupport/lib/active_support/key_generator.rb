require 'thread_safe'
require 'openssl'

module ActiveSupport
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

  class LegacyKeyGenerator # :nodoc:
    SECRET_MIN_LENGTH = 30 # Characters

    def initialize(secret)
      ensure_secret_secure(secret)
      @secret = secret
    end

    def generate_key(salt)
      @secret
    end

    private

    def ensure_secret_secure(secret)
      if secret.blank?
        raise ArgumentError, "A secret is required to generate an integrity hash " \
          "for cookie session data. Set a secret_key_base of at least " \
          "#{SECRET_MIN_LENGTH} characters in config/secrets.yml."
      end

      if secret.length < SECRET_MIN_LENGTH
        raise ArgumentError, "Secret should be something secure, " \
          "like \"#{SecureRandom.hex(16)}\". The value you " \
          "provided, \"#{secret}\", is shorter than the minimum length " \
          "of #{SECRET_MIN_LENGTH} characters."
      end
    end
  end
end
