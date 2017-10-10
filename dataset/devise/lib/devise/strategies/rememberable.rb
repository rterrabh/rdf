require 'devise/strategies/authenticatable'

module Devise
  module Strategies
    class Rememberable < Authenticatable
      def valid?
        @remember_cookie = nil
        remember_cookie.present?
      end

      def authenticate!
        resource = mapping.to.serialize_from_cookie(*remember_cookie)

        unless resource
          cookies.delete(remember_key)
          return pass
        end

        if validate(resource)
          remember_me(resource)
          extend_remember_me_period(resource)
          success!(resource)
        end
      end

    private

      def extend_remember_me_period(resource)
        if resource.respond_to?(:extend_remember_period=)
          resource.extend_remember_period = mapping.to.extend_remember_period
        end
      end

      def remember_me?
        true
      end

      def remember_key
        mapping.to.rememberable_options.fetch(:key, "remember_#{scope}_token")
      end

      def remember_cookie
        @remember_cookie ||= cookies.signed[remember_key]
      end

    end
  end
end

Warden::Strategies.add(:rememberable, Devise::Strategies::Rememberable)
