require 'rails_admin/config/fields/base'

module RailsAdmin
  module Config
    module Fields
      module Types
        class CodeMirror < RailsAdmin::Config::Fields::Types::Text
          RailsAdmin::Config::Fields::Types.register(self)

          register_instance_option :config do
            {
              mode: 'css',
              theme: 'night',
            }
          end

          register_instance_option :assets do
            {
              mode: '/assets/codemirror/modes/css.js',
              theme: '/assets/codemirror/themes/night.css',
            }
          end

          register_instance_option :js_location do
            '/assets/codemirror.js'
          end

          register_instance_option :css_location do
            '/assets/codemirror.css'
          end

          register_instance_option :partial do
            :form_code_mirror
          end

          [:assets, :config, :css_location, :js_location].each do |key|
            register_deprecated_instance_option :"codemirror_#{key}", key
          end
        end
      end
    end
  end
end
