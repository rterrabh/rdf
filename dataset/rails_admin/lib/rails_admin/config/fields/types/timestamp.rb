require 'rails_admin/config/fields/types/datetime'

module RailsAdmin
  module Config
    module Fields
      module Types
        class Timestamp < RailsAdmin::Config::Fields::Types::Datetime
          RailsAdmin::Config::Fields::Types.register(self)

          @format = :long
          @i18n_scope = [:time, :formats]
          @js_plugin_options = {}
        end
      end
    end
  end
end
