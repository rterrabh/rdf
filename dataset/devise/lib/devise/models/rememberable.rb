require 'devise/strategies/rememberable'
require 'devise/hooks/rememberable'
require 'devise/hooks/forgetable'

module Devise
  module Models
    module Rememberable
      extend ActiveSupport::Concern

      attr_accessor :remember_me, :extend_remember_period

      def self.required_fields(klass)
        [:remember_created_at]
      end

      def remember_me!(extend_period=false)
        self.remember_token = self.class.remember_token if generate_remember_token?
        self.remember_created_at = Time.now.utc if generate_remember_timestamp?(extend_period)
        save(validate: false) if self.changed?
      end

      def forget_me!
        return unless persisted?
        self.remember_token = nil if respond_to?(:remember_token=)
        self.remember_created_at = nil if self.class.expire_all_remember_me_on_sign_out
        save(validate: false)
      end

      def remember_expired?
        remember_created_at.nil? || (remember_expires_at <= Time.now.utc)
      end

      def remember_expires_at
        remember_created_at + self.class.remember_for
      end

      def rememberable_value
        if respond_to?(:remember_token)
          remember_token
        elsif respond_to?(:authenticatable_salt) && (salt = authenticatable_salt)
          salt
        else
          raise "authenticable_salt returned nil for the #{self.class.name} model. " \
            "In order to use rememberable, you must ensure a password is always set " \
            "or have a remember_token column in your model or implement your own " \
            "rememberable_value in the model with custom logic."
        end
      end

      def rememberable_options
        self.class.rememberable_options
      end

    protected

      def generate_remember_token? #:nodoc:
        respond_to?(:remember_token) && remember_expired?
      end

      def generate_remember_timestamp?(extend_period) #:nodoc:
        extend_period || remember_created_at.nil? || remember_expired?
      end

      module ClassMethods
        def serialize_into_cookie(record)
          [record.to_key, record.rememberable_value]
        end

        def serialize_from_cookie(id, remember_token)
          record = to_adapter.get(id)
          record if record && !record.remember_expired? &&
                    Devise.secure_compare(record.rememberable_value, remember_token)
        end

        def remember_token #:nodoc:
          loop do
            token = Devise.friendly_token
            break token unless to_adapter.find_first({ remember_token: token })
          end
        end

        Devise::Models.config(self, :remember_for, :extend_remember_period, :rememberable_options, :expire_all_remember_me_on_sign_out)
      end
    end
  end
end
