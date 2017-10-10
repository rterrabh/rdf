module Devise
  module Models
    module Registerable
      extend ActiveSupport::Concern

      def self.required_fields(klass)
        []
      end

      module ClassMethods
        def new_with_session(params, session)
          new(params)
        end
      end
    end
  end
end
