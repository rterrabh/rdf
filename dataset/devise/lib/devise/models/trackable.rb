require 'devise/hooks/trackable'

module Devise
  module Models
    module Trackable
      def self.required_fields(klass)
        [:current_sign_in_at, :current_sign_in_ip, :last_sign_in_at, :last_sign_in_ip, :sign_in_count]
      end

      def update_tracked_fields(request)
        old_current, new_current = self.current_sign_in_at, Time.now.utc
        self.last_sign_in_at     = old_current || new_current
        self.current_sign_in_at  = new_current

        old_current, new_current = self.current_sign_in_ip, request.remote_ip
        self.last_sign_in_ip     = old_current || new_current
        self.current_sign_in_ip  = new_current

        self.sign_in_count ||= 0
        self.sign_in_count += 1
      end

      def update_tracked_fields!(request)
        update_tracked_fields(request)
        save(validate: false) or raise "Devise trackable could not save #{inspect}." \
          "Please make sure a model using trackable can be saved at sign in."
      end
    end
  end
end
