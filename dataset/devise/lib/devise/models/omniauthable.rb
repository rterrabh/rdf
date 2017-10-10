require 'devise/omniauth'

module Devise
  module Models
    module Omniauthable
      extend ActiveSupport::Concern

      def self.required_fields(klass)
        []
      end

      module ClassMethods
        Devise::Models.config(self, :omniauth_providers)
      end
    end
  end
end
