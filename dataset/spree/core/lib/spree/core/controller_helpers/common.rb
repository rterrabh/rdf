module Spree
  module Core
    module ControllerHelpers
      module Common
        extend ActiveSupport::Concern
        included do
          helper_method :title
          helper_method :title=
          helper_method :accurate_title

          layout :get_layout

          before_filter :set_user_language

          protected

          attr_writer :title

          def title
            title_string = @title.present? ? @title : accurate_title
            if title_string.present?
              if Spree::Config[:always_put_site_name_in_title]
                [title_string, default_title].join(' - ')
              else
                title_string
              end
            else
              default_title
            end
          end

          def default_title
            current_store.name
          end

          def accurate_title
            current_store.seo_title
          end

          def render_404(exception = nil)
            respond_to do |type|
              type.html { render :status => :not_found, :file    => "#{::Rails.root}/public/404", :formats => [:html], :layout => nil}
              type.all  { render :status => :not_found, :nothing => true }
            end
          end

          private

          def set_user_language
            locale = session[:locale]
            locale ||= config_locale if respond_to?(:config_locale, true)
            locale ||= Rails.application.config.i18n.default_locale
            locale ||= I18n.default_locale unless I18n.available_locales.map(&:to_s).include?(locale)
            I18n.locale = locale
          end

          def get_layout
            layout ||= Spree::Config[:layout]
          end

        end
      end
    end
  end
end
