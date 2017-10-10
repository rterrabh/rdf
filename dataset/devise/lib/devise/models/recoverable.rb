module Devise
  module Models

    module Recoverable
      extend ActiveSupport::Concern

      def self.required_fields(klass)
        [:reset_password_sent_at, :reset_password_token]
      end

      def reset_password!(new_password, new_password_confirmation)
        self.password = new_password
        self.password_confirmation = new_password_confirmation

        if valid?
          clear_reset_password_token
          after_password_reset
        end

        save
      end

      def send_reset_password_instructions
        token = set_reset_password_token
        send_reset_password_instructions_notification(token)

        token
      end

      def reset_password_period_valid?
        reset_password_sent_at && reset_password_sent_at.utc >= self.class.reset_password_within.ago
      end

      protected

        def clear_reset_password_token
          self.reset_password_token = nil
          self.reset_password_sent_at = nil
        end

        def after_password_reset
        end

        def set_reset_password_token
          raw, enc = Devise.token_generator.generate(self.class, :reset_password_token)

          self.reset_password_token   = enc
          self.reset_password_sent_at = Time.now.utc
          self.save(validate: false)
          raw
        end

        def send_reset_password_instructions_notification(token)
          send_devise_notification(:reset_password_instructions, token, {})
        end

      module ClassMethods
        def with_reset_password_token(token)
          reset_password_token = Devise.token_generator.digest(self, :reset_password_token, token)
          to_adapter.find_first(reset_password_token: reset_password_token)
        end

        def send_reset_password_instructions(attributes={})
          recoverable = find_or_initialize_with_errors(reset_password_keys, attributes, :not_found)
          recoverable.send_reset_password_instructions if recoverable.persisted?
          recoverable
        end

        def reset_password_by_token(attributes={})
          original_token       = attributes[:reset_password_token]
          reset_password_token = Devise.token_generator.digest(self, :reset_password_token, original_token)

          recoverable = find_or_initialize_with_error_by(:reset_password_token, reset_password_token)

          if recoverable.persisted?
            if recoverable.reset_password_period_valid?
              recoverable.reset_password!(attributes[:password], attributes[:password_confirmation])
            else
              recoverable.errors.add(:reset_password_token, :expired)
            end
          end

          recoverable.reset_password_token = original_token
          recoverable
        end

        Devise::Models.config(self, :reset_password_keys, :reset_password_within)
      end
    end
  end
end
