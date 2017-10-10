require 'base64'
require 'active_support/core_ext/object/blank'
require 'active_support/security_utils'

module ActiveSupport
  class MessageVerifier
    class InvalidSignature < StandardError; end

    def initialize(secret, options = {})
      raise ArgumentError, 'Secret should not be nil.' unless secret
      @secret = secret
      @digest = options[:digest] || 'SHA1'
      @serializer = options[:serializer] || Marshal
    end

    def verify(signed_message)
      raise InvalidSignature if signed_message.blank?

      data, digest = signed_message.split("--")
      if data.present? && digest.present? && ActiveSupport::SecurityUtils.secure_compare(digest, generate_digest(data))
        begin
          @serializer.load(decode(data))
        rescue ArgumentError => argument_error
          raise InvalidSignature if argument_error.message =~ %r{invalid base64}
          raise
        end
      else
        raise InvalidSignature
      end
    end

    def generate(value)
      data = encode(@serializer.dump(value))
      "#{data}--#{generate_digest(data)}"
    end

    private
      def encode(data)
        ::Base64.strict_encode64(data)
      end

      def decode(data)
        ::Base64.strict_decode64(data)
      end

      def generate_digest(data)
        require 'openssl' unless defined?(OpenSSL)
        #nodyna <const_get-1004> <CG COMPLEX (change-prone variable)>
        OpenSSL::HMAC.hexdigest(OpenSSL::Digest.const_get(@digest).new, @secret, data)
      end
  end
end
