require "devise/hooks/lockable"

module Devise
  module Models
    module Lockable
      extend  ActiveSupport::Concern

      delegate :lock_strategy_enabled?, :unlock_strategy_enabled?, to: "self.class"

      def self.required_fields(klass)
        attributes = []
        attributes << :failed_attempts if klass.lock_strategy_enabled?(:failed_attempts)
        attributes << :locked_at if klass.unlock_strategy_enabled?(:time)
        attributes << :unlock_token if klass.unlock_strategy_enabled?(:email)

        attributes
      end

      def lock_access!(opts = { })
        self.locked_at = Time.now.utc

        if unlock_strategy_enabled?(:email) && opts.fetch(:send_instructions, true)
          send_unlock_instructions
        else
          save(validate: false)
        end
      end

      def unlock_access!
        self.locked_at = nil
        self.failed_attempts = 0 if respond_to?(:failed_attempts=)
        self.unlock_token = nil  if respond_to?(:unlock_token=)
        save(validate: false)
      end

      def access_locked?
        !!locked_at && !lock_expired?
      end

      def send_unlock_instructions
        raw, enc = Devise.token_generator.generate(self.class, :unlock_token)
        self.unlock_token = enc
        self.save(validate: false)
        send_devise_notification(:unlock_instructions, raw, {})
        raw
      end

      def resend_unlock_instructions
        if_access_locked { send_unlock_instructions }
      end

      def active_for_authentication?
        super && !access_locked?
      end

      def inactive_message
        access_locked? ? :locked : super
      end

      def valid_for_authentication?
        return super unless persisted? && lock_strategy_enabled?(:failed_attempts)

        unlock_access! if lock_expired?

        if super && !access_locked?
          true
        else
          self.failed_attempts ||= 0
          self.failed_attempts += 1
          if attempts_exceeded?
            lock_access! unless access_locked?
          else
            save(validate: false)
          end
          false
        end
      end

      def unauthenticated_message
        if Devise.paranoid
          super
        elsif access_locked? || (lock_strategy_enabled?(:failed_attempts) && attempts_exceeded?)
          :locked
        elsif lock_strategy_enabled?(:failed_attempts) && last_attempt? && self.class.last_attempt_warning
          :last_attempt
        else
          super
        end
      end

      protected

        def attempts_exceeded?
          self.failed_attempts >= self.class.maximum_attempts
        end

        def last_attempt?
          self.failed_attempts == self.class.maximum_attempts - 1
        end

        def lock_expired?
          if unlock_strategy_enabled?(:time)
            locked_at && locked_at < self.class.unlock_in.ago
          else
            false
          end
        end

        def if_access_locked
          if access_locked?
            yield
          else
            self.errors.add(Devise.unlock_keys.first, :not_locked)
            false
          end
        end

      module ClassMethods
        def send_unlock_instructions(attributes={})
          lockable = find_or_initialize_with_errors(unlock_keys, attributes, :not_found)
          lockable.resend_unlock_instructions if lockable.persisted?
          lockable
        end

        def unlock_access_by_token(unlock_token)
          original_token = unlock_token
          unlock_token   = Devise.token_generator.digest(self, :unlock_token, unlock_token)

          lockable = find_or_initialize_with_error_by(:unlock_token, unlock_token)
          lockable.unlock_access! if lockable.persisted?
          lockable.unlock_token = original_token
          lockable
        end

        def unlock_strategy_enabled?(strategy)
          [:both, strategy].include?(self.unlock_strategy)
        end

        def lock_strategy_enabled?(strategy)
          self.lock_strategy == strategy
        end

        Devise::Models.config(self, :maximum_attempts, :lock_strategy, :unlock_strategy, :unlock_in, :unlock_keys, :last_attempt_warning)
      end
    end
  end
end
