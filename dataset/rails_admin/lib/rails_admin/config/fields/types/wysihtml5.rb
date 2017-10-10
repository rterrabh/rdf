require 'rails_admin/config/fields/base'

module RailsAdmin
  module Config
    module Fields
      module Types
        class Wysihtml5 < RailsAdmin::Config::Fields::Types::Text
          RailsAdmin::Config::Fields::Types.register(self)

          register_instance_option :config_options do
            nil
          end

          register_instance_option :css_location do
            ActionController::Base.helpers.asset_path('bootstrap-wysihtml5.css')
          end

          register_instance_option :js_location do
            ActionController::Base.helpers.asset_path('bootstrap-wysihtml5.js')
          end

          register_instance_option :partial do
            :form_wysihtml5
          end

          [:config_options, :css_location, :js_location].each do |key|
            register_deprecated_instance_option :"bootstrap_wysihtml5_#{key}", key
          end
        end
      end
    end
  end
end
