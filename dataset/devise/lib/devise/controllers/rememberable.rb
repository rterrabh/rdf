module Devise
  module Controllers
    module Rememberable
      def self.cookie_values
        Rails.configuration.session_options.slice(:path, :domain, :secure)
      end

      def remember_me(resource)
        return if env["devise.skip_storage"]
        scope = Devise::Mapping.find_scope!(resource)
        resource.remember_me!(resource.extend_remember_period)
        cookies.signed[remember_key(resource, scope)] = remember_cookie_values(resource)
      end

      def forget_me(resource)
        scope = Devise::Mapping.find_scope!(resource)
        resource.forget_me!
        cookies.delete(remember_key(resource, scope), forget_cookie_values(resource))
      end

      protected

      def forget_cookie_values(resource)
        Devise::Controllers::Rememberable.cookie_values.merge!(resource.rememberable_options)
      end

      def remember_cookie_values(resource)
        options = { httponly: true }
        options.merge!(forget_cookie_values(resource))
        options.merge!(
          value: resource.class.serialize_into_cookie(resource),
          expires: resource.remember_expires_at
        )
      end

      def remember_key(resource, scope)
        resource.rememberable_options.fetch(:key, "remember_#{scope}_token")
      end
    end
  end
end
