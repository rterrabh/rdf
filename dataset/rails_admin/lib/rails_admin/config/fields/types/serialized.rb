require 'rails_admin/config/fields/types/text'

module RailsAdmin
  module Config
    module Fields
      module Types
        class Serialized < RailsAdmin::Config::Fields::Types::Text
          RailsAdmin::Config::Fields::Types.register(self)

          register_instance_option :formatted_value do
            YAML.dump(value) unless value.nil?
          end

          def parse_input(params)
            return unless params[name].is_a?(::String)
            params[name] = (params[name].blank? ? nil : (SafeYAML.load(params[name]) || nil))
          end
        end
      end
    end
  end
end
