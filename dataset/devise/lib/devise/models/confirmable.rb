module Devise
  module Models
    module Confirmable
      extend ActiveSupport::Concern
      include ActionView::Helpers::DateHelper

      included do
        before_create :generate_confirmation_token, if: :confirmation_required?
        after_create  :send_on_create_confirmation_instructions, if: :send_confirmation_notification?
        before_update :postpone_email_change_until_confirmation_and_regenerate_confirmation_token, if: :postpone_email_change?
        after_update  :send_reconfirmation_instructions,  if: :reconfirmation_required?
      end

      def initialize(*args, &block)
        @bypass_confirmation_postpone = false
        @reconfirmation_required = false
        @skip_confirmation_notification = false
        @raw_confirmation_token = nil
        super
      end

      def self.required_fields(klass)
        required_methods = [:confirmation_token, :confirmed_at, :confirmation_sent_at]
        required_methods << :unconfirmed_email if klass.reconfirmable
        required_methods
      end

      def confirm!
        pending_any_confirmation do
          if confirmation_period_expired?
            self.errors.add(:email, :confirmation_period_expired,
              period: Devise::TimeInflector.time_ago_in_words(self.class.confirm_within.ago))
            return false
          end

          self.confirmation_token = nil
          self.confirmed_at = Time.now.utc

          saved = if self.class.reconfirmable && unconfirmed_email.present?
            skip_reconfirmation!
            self.email = unconfirmed_email
            self.unconfirmed_email = nil

            save(validate: true)
          else
            save(validate: false)
          end

          after_confirmation if saved
          saved
        end
      end

      def confirmed?
        !!confirmed_at
      end

      def pending_reconfirmation?
        self.class.reconfirmable && unconfirmed_email.present?
      end

      def send_confirmation_instructions
        unless @raw_confirmation_token
          generate_confirmation_token!
        end

        opts = pending_reconfirmation? ? { to: unconfirmed_email } : { }
        send_devise_notification(:confirmation_instructions, @raw_confirmation_token, opts)
      end

      def send_reconfirmation_instructions
        @reconfirmation_required = false

        unless @skip_confirmation_notification
          send_confirmation_instructions
        end
      end

      def resend_confirmation_instructions
        pending_any_confirmation do
          send_confirmation_instructions
        end
      end

      def active_for_authentication?
        super && (!confirmation_required? || confirmed? || confirmation_period_valid?)
      end

      def inactive_message
        !confirmed? ? :unconfirmed : super
      end

      def skip_confirmation!
        self.confirmed_at = Time.now.utc
      end

      def skip_confirmation_notification!
        @skip_confirmation_notification = true
      end

      def skip_reconfirmation!
        @bypass_confirmation_postpone = true
      end

      protected

        def send_on_create_confirmation_instructions
          send_confirmation_instructions
        end

        def confirmation_required?
          !confirmed?
        end

        def confirmation_period_valid?
          self.class.allow_unconfirmed_access_for.nil? || (confirmation_sent_at && confirmation_sent_at.utc >= self.class.allow_unconfirmed_access_for.ago)
        end

        def confirmation_period_expired?
          self.class.confirm_within && (Time.now > self.confirmation_sent_at + self.class.confirm_within )
        end

        def pending_any_confirmation
          if (!confirmed? || pending_reconfirmation?)
            yield
          else
            self.errors.add(:email, :already_confirmed)
            false
          end
        end

        def generate_confirmation_token
          raw, enc = Devise.token_generator.generate(self.class, :confirmation_token)
          @raw_confirmation_token   = raw
          self.confirmation_token   = enc
          self.confirmation_sent_at = Time.now.utc
        end

        def generate_confirmation_token!
          generate_confirmation_token && save(validate: false)
        end

        def postpone_email_change_until_confirmation_and_regenerate_confirmation_token
          @reconfirmation_required = true
          self.unconfirmed_email = self.email
          self.email = self.email_was
          generate_confirmation_token
        end

        def postpone_email_change?
          postpone = self.class.reconfirmable && email_changed? && !@bypass_confirmation_postpone && self.email.present?
          @bypass_confirmation_postpone = false
          postpone
        end

        def reconfirmation_required?
          self.class.reconfirmable && @reconfirmation_required && self.email.present?
        end

        def send_confirmation_notification?
          confirmation_required? && !@skip_confirmation_notification && self.email.present?
        end

        def after_confirmation
        end

      module ClassMethods
        def send_confirmation_instructions(attributes={})
          confirmable = find_by_unconfirmed_email_with_errors(attributes) if reconfirmable
          unless confirmable.try(:persisted?)
            confirmable = find_or_initialize_with_errors(confirmation_keys, attributes, :not_found)
          end
          confirmable.resend_confirmation_instructions if confirmable.persisted?
          confirmable
        end

        def confirm_by_token(confirmation_token)
          original_token     = confirmation_token
          confirmation_token = Devise.token_generator.digest(self, :confirmation_token, confirmation_token)

          confirmable = find_or_initialize_with_error_by(:confirmation_token, confirmation_token)
          confirmable.confirm! if confirmable.persisted?
          confirmable.confirmation_token = original_token
          confirmable
        end

        def find_by_unconfirmed_email_with_errors(attributes = {})
          unconfirmed_required_attributes = confirmation_keys.map { |k| k == :email ? :unconfirmed_email : k }
          unconfirmed_attributes = attributes.symbolize_keys
          unconfirmed_attributes[:unconfirmed_email] = unconfirmed_attributes.delete(:email)
          find_or_initialize_with_errors(unconfirmed_required_attributes, unconfirmed_attributes, :not_found)
        end

        Devise::Models.config(self, :allow_unconfirmed_access_for, :confirmation_keys, :reconfirmable, :confirm_within)
      end
    end
  end
end
