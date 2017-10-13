require 'devise/hooks/activatable'
require 'devise/hooks/csrf_cleaner'

module Devise
  module Models
    module Authenticatable
      extend ActiveSupport::Concern

      BLACKLIST_FOR_SERIALIZATION = [:encrypted_password, :reset_password_token, :reset_password_sent_at,
        :remember_created_at, :sign_in_count, :current_sign_in_at, :last_sign_in_at, :current_sign_in_ip,
        :last_sign_in_ip, :password_salt, :confirmation_token, :confirmed_at, :confirmation_sent_at,
        :remember_token, :unconfirmed_email, :failed_attempts, :unlock_token, :locked_at]

      included do
        class_attribute :devise_modules, instance_writer: false
        self.devise_modules ||= []

        before_validation :downcase_keys
        before_validation :strip_whitespace
      end

      def self.required_fields(klass)
        []
      end

      def valid_for_authentication?
        block_given? ? yield : true
      end

      def unauthenticated_message
        :invalid
      end

      def active_for_authentication?
        true
      end

      def inactive_message
        :inactive
      end

      def authenticatable_salt
      end

      array = %w(serializable_hash)
      array << "to_xml" if Rails::VERSION::STRING[0,3] == "3.1"

      array.each do |method|
        #nodyna <class_eval-2747> <CE MODERATE (define methods)>
        class_eval <<-RUBY, __FILE__, __LINE__
          def #{method}(options=nil)
            options ||= {}
            options[:except] = Array(options[:except])

            if options[:force_except]
              options[:except].concat Array(options[:force_except])
            else
              options[:except].concat BLACKLIST_FOR_SERIALIZATION
            end
            super(options)
          end
        RUBY
      end

      protected

      def devise_mailer
        Devise.mailer
      end

      def send_devise_notification(notification, *args)
        #nodyna <send-2748> <SD MODERATE (change-prone variable)>
        message = devise_mailer.send(notification, self, *args)
        if message.respond_to?(:deliver_now)
          message.deliver_now
        else
          message.deliver
        end
      end

      def downcase_keys
        self.class.case_insensitive_keys.each { |k| apply_to_attribute_or_variable(k, :downcase) }
      end

      def strip_whitespace
        self.class.strip_whitespace_keys.each { |k| apply_to_attribute_or_variable(k, :strip) }
      end

      def apply_to_attribute_or_variable(attr, method)
        if self[attr]
          self[attr] = self[attr].try(method)

        elsif respond_to?(attr) && respond_to?("#{attr}=")
          #nodyna <send-2749> <SD COMPLEX (change-prone variable)>
          new_value = send(attr).try(method)
          #nodyna <send-2750> <SD COMPLEX (change-prone variable)>
          send("#{attr}=", new_value)
        end
      end

      module ClassMethods
        Devise::Models.config(self, :authentication_keys, :request_keys, :strip_whitespace_keys,
          :case_insensitive_keys, :http_authenticatable, :params_authenticatable, :skip_session_storage,
          :http_authentication_key)

        def serialize_into_session(record)
          [record.to_key, record.authenticatable_salt]
        end

        def serialize_from_session(key, salt)
          record = to_adapter.get(key)
          record if record && record.authenticatable_salt == salt
        end

        def params_authenticatable?(strategy)
          params_authenticatable.is_a?(Array) ?
            params_authenticatable.include?(strategy) : params_authenticatable
        end

        def http_authenticatable?(strategy)
          http_authenticatable.is_a?(Array) ?
            http_authenticatable.include?(strategy) : http_authenticatable
        end

        def find_for_authentication(tainted_conditions)
          find_first_by_auth_conditions(tainted_conditions)
        end

        def find_first_by_auth_conditions(tainted_conditions, opts={})
          to_adapter.find_first(devise_parameter_filter.filter(tainted_conditions).merge(opts))
        end

        def find_or_initialize_with_error_by(attribute, value, error=:invalid) #:nodoc:
          find_or_initialize_with_errors([attribute], { attribute => value }, error)
        end

        def find_or_initialize_with_errors(required_attributes, attributes, error=:invalid) #:nodoc:
          attributes = attributes.slice(*required_attributes).with_indifferent_access
          attributes.delete_if { |key, value| value.blank? }

          if attributes.size == required_attributes.size
            record = find_first_by_auth_conditions(attributes)
          end

          unless record
            record = new

            required_attributes.each do |key|
              value = attributes[key]
              #nodyna <send-2751> <SD COMPLEX (array)>
              record.send("#{key}=", value)
              record.errors.add(key, value.present? ? error : :blank)
            end
          end

          record
        end

        protected

        def devise_parameter_filter
          @devise_parameter_filter ||= Devise::ParameterFilter.new(case_insensitive_keys, strip_whitespace_keys)
        end
      end
    end
  end
end
