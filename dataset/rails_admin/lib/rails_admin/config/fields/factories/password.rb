require 'rails_admin/config/fields'
require 'rails_admin/config/fields/types/password'

RailsAdmin::Config::Fields.register_factory do |parent, properties, fields|
  if [:password].include?(properties.name)
    fields << RailsAdmin::Config::Fields::Types::Password.new(parent, properties.name, properties)
    true
  else
    false
  end
end
