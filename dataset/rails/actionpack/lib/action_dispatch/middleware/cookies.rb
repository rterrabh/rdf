require 'active_support/core_ext/hash/keys'
require 'active_support/core_ext/module/attribute_accessors'
require 'active_support/core_ext/object/blank'
require 'active_support/key_generator'
require 'active_support/message_verifier'
require 'active_support/json'

module ActionDispatch
  class Request < Rack::Request
    def cookie_jar
      env['action_dispatch.cookies'] ||= Cookies::CookieJar.build(self)
    end
  end

  class Cookies
    HTTP_HEADER   = "Set-Cookie".freeze
    GENERATOR_KEY = "action_dispatch.key_generator".freeze
    SIGNED_COOKIE_SALT = "action_dispatch.signed_cookie_salt".freeze
    ENCRYPTED_COOKIE_SALT = "action_dispatch.encrypted_cookie_salt".freeze
    ENCRYPTED_SIGNED_COOKIE_SALT = "action_dispatch.encrypted_signed_cookie_salt".freeze
    SECRET_TOKEN = "action_dispatch.secret_token".freeze
    SECRET_KEY_BASE = "action_dispatch.secret_key_base".freeze
    COOKIES_SERIALIZER = "action_dispatch.cookies_serializer".freeze
    COOKIES_DIGEST = "action_dispatch.cookies_digest".freeze

    MAX_COOKIE_SIZE = 4096

    CookieOverflow = Class.new StandardError

    module ChainedCookieJars
      def permanent
        @permanent ||= PermanentCookieJar.new(self, @key_generator, @options)
      end

      def signed
        @signed ||=
          if @options[:upgrade_legacy_signed_cookies]
            UpgradeLegacySignedCookieJar.new(self, @key_generator, @options)
          else
            SignedCookieJar.new(self, @key_generator, @options)
          end
      end

      def encrypted
        @encrypted ||=
          if @options[:upgrade_legacy_signed_cookies]
            UpgradeLegacyEncryptedCookieJar.new(self, @key_generator, @options)
          else
            EncryptedCookieJar.new(self, @key_generator, @options)
          end
      end

      def signed_or_encrypted
        @signed_or_encrypted ||=
          if @options[:secret_key_base].present?
            encrypted
          else
            signed
          end
      end
    end

    module VerifyAndUpgradeLegacySignedMessage # :nodoc:
      def initialize(*args)
        super
        @legacy_verifier = ActiveSupport::MessageVerifier.new(@options[:secret_token], serializer: ActiveSupport::MessageEncryptor::NullSerializer)
      end

      def verify_and_upgrade_legacy_signed_message(name, signed_message)
        deserialize(name, @legacy_verifier.verify(signed_message)).tap do |value|
          self[name] = { value: value }
        end
      rescue ActiveSupport::MessageVerifier::InvalidSignature
        nil
      end
    end

    class CookieJar #:nodoc:
      include Enumerable, ChainedCookieJars

      DOMAIN_REGEXP = /[^.]*\.([^.]*|..\...|...\...)$/

      def self.options_for_env(env) #:nodoc:
        { signed_cookie_salt: env[SIGNED_COOKIE_SALT] || '',
          encrypted_cookie_salt: env[ENCRYPTED_COOKIE_SALT] || '',
          encrypted_signed_cookie_salt: env[ENCRYPTED_SIGNED_COOKIE_SALT] || '',
          secret_token: env[SECRET_TOKEN],
          secret_key_base: env[SECRET_KEY_BASE],
          upgrade_legacy_signed_cookies: env[SECRET_TOKEN].present? && env[SECRET_KEY_BASE].present?,
          serializer: env[COOKIES_SERIALIZER],
          digest: env[COOKIES_DIGEST]
        }
      end

      def self.build(request)
        env = request.env
        key_generator = env[GENERATOR_KEY]
        options = options_for_env env

        host = request.host
        secure = request.ssl?

        new(key_generator, host, secure, options).tap do |hash|
          hash.update(request.cookies)
        end
      end

      def initialize(key_generator, host = nil, secure = false, options = {})
        @key_generator = key_generator
        @set_cookies = {}
        @delete_cookies = {}
        @host = host
        @secure = secure
        @options = options
        @cookies = {}
        @committed = false
      end

      def committed?; @committed; end

      def commit!
        @committed = true
        @set_cookies.freeze
        @delete_cookies.freeze
      end

      def each(&block)
        @cookies.each(&block)
      end

      def [](name)
        @cookies[name.to_s]
      end

      def fetch(name, *args, &block)
        @cookies.fetch(name.to_s, *args, &block)
      end

      def key?(name)
        @cookies.key?(name.to_s)
      end
      alias :has_key? :key?

      def update(other_hash)
        @cookies.update other_hash.stringify_keys
        self
      end

      def handle_options(options) #:nodoc:
        options[:path] ||= "/"

        if options[:domain] == :all
          domain_regexp = options[:tld_length] ? /([^.]+\.?){#{options[:tld_length]}}$/ : DOMAIN_REGEXP

          options[:domain] = if (@host !~ /^[\d.]+$/) && (@host =~ domain_regexp)
            ".#{$&}"
          end
        elsif options[:domain].is_a? Array
          options[:domain] = options[:domain].find {|domain| @host.include? domain.sub(/^\./, '') }
        end
      end

      def []=(name, options)
        if options.is_a?(Hash)
          options.symbolize_keys!
          value = options[:value]
        else
          value = options
          options = { :value => value }
        end

        handle_options(options)

        if @cookies[name.to_s] != value or options[:expires]
          @cookies[name.to_s] = value
          @set_cookies[name.to_s] = options
          @delete_cookies.delete(name.to_s)
        end

        value
      end

      def delete(name, options = {})
        return unless @cookies.has_key? name.to_s

        options.symbolize_keys!
        handle_options(options)

        value = @cookies.delete(name.to_s)
        @delete_cookies[name.to_s] = options
        value
      end

      def deleted?(name, options = {})
        options.symbolize_keys!
        handle_options(options)
        @delete_cookies[name.to_s] == options
      end

      def clear(options = {})
        @cookies.each_key{ |k| delete(k, options) }
      end

      def write(headers)
        @set_cookies.each { |k, v| ::Rack::Utils.set_cookie_header!(headers, k, v) if write_cookie?(v) }
        @delete_cookies.each { |k, v| ::Rack::Utils.delete_cookie_header!(headers, k, v) }
      end

      def recycle! #:nodoc:
        @set_cookies = {}
        @delete_cookies = {}
      end

      mattr_accessor :always_write_cookie
      self.always_write_cookie = false

      private
        def write_cookie?(cookie)
          @secure || !cookie[:secure] || always_write_cookie
        end
    end

    class PermanentCookieJar #:nodoc:
      include ChainedCookieJars

      def initialize(parent_jar, key_generator, options = {})
        @parent_jar = parent_jar
        @key_generator = key_generator
        @options = options
      end

      def [](name)
        @parent_jar[name.to_s]
      end

      def []=(name, options)
        if options.is_a?(Hash)
          options.symbolize_keys!
        else
          options = { :value => options }
        end

        options[:expires] = 20.years.from_now
        @parent_jar[name] = options
      end
    end

    class JsonSerializer # :nodoc:
      def self.load(value)
        ActiveSupport::JSON.decode(value)
      end

      def self.dump(value)
        ActiveSupport::JSON.encode(value)
      end
    end

    module SerializedCookieJars # :nodoc:
      MARSHAL_SIGNATURE = "\x04\x08".freeze

      protected
        def needs_migration?(value)
          @options[:serializer] == :hybrid && value.start_with?(MARSHAL_SIGNATURE)
        end

        def serialize(name, value)
          serializer.dump(value)
        end

        def deserialize(name, value)
          if value
            if needs_migration?(value)
              Marshal.load(value).tap do |v|
                self[name] = { value: v }
              end
            else
              serializer.load(value)
            end
          end
        end

        def serializer
          serializer = @options[:serializer] || :marshal
          case serializer
          when :marshal
            Marshal
          when :json, :hybrid
            JsonSerializer
          else
            serializer
          end
        end

        def digest
          @options[:digest] || 'SHA1'
        end
    end

    class SignedCookieJar #:nodoc:
      include ChainedCookieJars
      include SerializedCookieJars

      def initialize(parent_jar, key_generator, options = {})
        @parent_jar = parent_jar
        @options = options
        secret = key_generator.generate_key(@options[:signed_cookie_salt])
        @verifier = ActiveSupport::MessageVerifier.new(secret, digest: digest, serializer: ActiveSupport::MessageEncryptor::NullSerializer)
      end

      def [](name)
        if signed_message = @parent_jar[name]
          deserialize name, verify(signed_message)
        end
      end

      def []=(name, options)
        if options.is_a?(Hash)
          options.symbolize_keys!
          options[:value] = @verifier.generate(serialize(name, options[:value]))
        else
          options = { :value => @verifier.generate(serialize(name, options)) }
        end

        raise CookieOverflow if options[:value].bytesize > MAX_COOKIE_SIZE
        @parent_jar[name] = options
      end

      private
        def verify(signed_message)
          @verifier.verify(signed_message)
        rescue ActiveSupport::MessageVerifier::InvalidSignature
          nil
        end
    end

    class UpgradeLegacySignedCookieJar < SignedCookieJar #:nodoc:
      include VerifyAndUpgradeLegacySignedMessage

      def [](name)
        if signed_message = @parent_jar[name]
          deserialize(name, verify(signed_message)) || verify_and_upgrade_legacy_signed_message(name, signed_message)
        end
      end
    end

    class EncryptedCookieJar #:nodoc:
      include ChainedCookieJars
      include SerializedCookieJars

      def initialize(parent_jar, key_generator, options = {})
        if ActiveSupport::LegacyKeyGenerator === key_generator
          raise "You didn't set secrets.secret_key_base, which is required for this cookie jar. " +
            "Read the upgrade documentation to learn more about this new config option."
        end

        @parent_jar = parent_jar
        @options = options
        secret = key_generator.generate_key(@options[:encrypted_cookie_salt])
        sign_secret = key_generator.generate_key(@options[:encrypted_signed_cookie_salt])
        @encryptor = ActiveSupport::MessageEncryptor.new(secret, sign_secret, digest: digest, serializer: ActiveSupport::MessageEncryptor::NullSerializer)
      end

      def [](name)
        if encrypted_message = @parent_jar[name]
          deserialize name, decrypt_and_verify(encrypted_message)
        end
      end

      def []=(name, options)
        if options.is_a?(Hash)
          options.symbolize_keys!
        else
          options = { :value => options }
        end

        options[:value] = @encryptor.encrypt_and_sign(serialize(name, options[:value]))

        raise CookieOverflow if options[:value].bytesize > MAX_COOKIE_SIZE
        @parent_jar[name] = options
      end

      private
        def decrypt_and_verify(encrypted_message)
          @encryptor.decrypt_and_verify(encrypted_message)
        rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveSupport::MessageEncryptor::InvalidMessage
          nil
        end
    end

    class UpgradeLegacyEncryptedCookieJar < EncryptedCookieJar #:nodoc:
      include VerifyAndUpgradeLegacySignedMessage

      def [](name)
        if encrypted_or_signed_message = @parent_jar[name]
          deserialize(name, decrypt_and_verify(encrypted_or_signed_message)) || verify_and_upgrade_legacy_signed_message(name, encrypted_or_signed_message)
        end
      end
    end

    def initialize(app)
      @app = app
    end

    def call(env)
      status, headers, body = @app.call(env)

      if cookie_jar = env['action_dispatch.cookies']
        unless cookie_jar.committed?
          cookie_jar.write(headers)
          if headers[HTTP_HEADER].respond_to?(:join)
            headers[HTTP_HEADER] = headers[HTTP_HEADER].join("\n")
          end
        end
      end

      [status, headers, body]
    end
  end
end
