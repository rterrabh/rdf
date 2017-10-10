module ActiveModel
  module SecurePassword
    extend ActiveSupport::Concern

    MAX_PASSWORD_LENGTH_ALLOWED = 72

    class << self
      attr_accessor :min_cost # :nodoc:
    end
    self.min_cost = false

    module ClassMethods
      def has_secure_password(options = {})
        begin
          require 'bcrypt'
        rescue LoadError
          $stderr.puts "You don't have bcrypt installed in your application. Please add it to your Gemfile and run bundle install"
          raise
        end

        include InstanceMethodsOnActivation

        if options.fetch(:validations, true)
          include ActiveModel::Validations

          validate do |record|
            record.errors.add(:password, :blank) unless record.password_digest.present?
          end

          validates_length_of :password, maximum: ActiveModel::SecurePassword::MAX_PASSWORD_LENGTH_ALLOWED
          validates_confirmation_of :password, allow_blank: true
        end

        if respond_to?(:attributes_protected_by_default)
          def self.attributes_protected_by_default #:nodoc:
            super + ['password_digest']
          end
        end
      end
    end

    module InstanceMethodsOnActivation
      def authenticate(unencrypted_password)
        BCrypt::Password.new(password_digest) == unencrypted_password && self
      end

      attr_reader :password

      def password=(unencrypted_password)
        if unencrypted_password.nil?
          self.password_digest = nil
        elsif !unencrypted_password.empty?
          @password = unencrypted_password
          cost = ActiveModel::SecurePassword.min_cost ? BCrypt::Engine::MIN_COST : BCrypt::Engine.cost
          self.password_digest = BCrypt::Password.create(unencrypted_password, cost: cost)
        end
      end

      def password_confirmation=(unencrypted_password)
        @password_confirmation = unencrypted_password
      end
    end
  end
end
