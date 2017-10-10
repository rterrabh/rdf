require 'rails_admin/config/fields/base'

module RailsAdmin
  module Config
    module Fields
      module Types
        class Float < RailsAdmin::Config::Fields::Base
          RailsAdmin::Config::Fields::Types.register(self)
        end
      end
    end
  end
end
