require 'openssl'
require 'base64'
require 'active_support/core_ext/array/extract_options'

module ActiveSupport
  class MessageEncryptor
    module NullSerializer #:nodoc:
      def self.load(value)
        value
      end

      def self.dump(value)
        value
      end
    end

    class InvalidMessage < StandardError; end
    OpenSSLCipherError = OpenSSL::Cipher::CipherError

    def initialize(secret, *signature_key_or_options)
      options = signature_key_or_options.extract_options!
      sign_secret = signature_key_or_options.first
      @secret = secret
      @sign_secret = sign_secret
      @cipher = options[:cipher] || 'aes-256-cbc'
      @verifier = MessageVerifier.new(@sign_secret || @secret, digest: options[:digest] || 'SHA1', serializer: NullSerializer)
      @serializer = options[:serializer] || Marshal
    end

    def encrypt_and_sign(value)
      verifier.generate(_encrypt(value))
    end

    def decrypt_and_verify(value)
      _decrypt(verifier.verify(value))
    end

    private

    def _encrypt(value)
      cipher = new_cipher
      cipher.encrypt
      cipher.key = @secret

      iv = cipher.random_iv

      encrypted_data = cipher.update(@serializer.dump(value))
      encrypted_data << cipher.final

      "#{::Base64.strict_encode64 encrypted_data}--#{::Base64.strict_encode64 iv}"
    end

    def _decrypt(encrypted_message)
      cipher = new_cipher
      encrypted_data, iv = encrypted_message.split("--").map {|v| ::Base64.strict_decode64(v)}

      cipher.decrypt
      cipher.key = @secret
      cipher.iv  = iv

      decrypted_data = cipher.update(encrypted_data)
      decrypted_data << cipher.final

      @serializer.load(decrypted_data)
    rescue OpenSSLCipherError, TypeError, ArgumentError
      raise InvalidMessage
    end

    def new_cipher
      OpenSSL::Cipher::Cipher.new(@cipher)
    end

    def verifier
      @verifier
    end
  end
end
