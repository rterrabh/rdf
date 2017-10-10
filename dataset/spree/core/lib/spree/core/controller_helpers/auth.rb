module Spree
  module Core
    module ControllerHelpers
      module Auth
        extend ActiveSupport::Concern

        included do
          before_filter :set_guest_token
          helper_method :try_spree_current_user

          rescue_from CanCan::AccessDenied do |exception|
            redirect_unauthorized_access
          end
        end

        def current_ability
          @current_ability ||= Spree::Ability.new(try_spree_current_user)
        end

        def redirect_back_or_default(default)
          redirect_to(session["spree_user_return_to"] || request.env["HTTP_REFERER"] || default)
          session["spree_user_return_to"] = nil
        end

        def set_guest_token
          unless cookies.signed[:guest_token].present?
            cookies.permanent.signed[:guest_token] = SecureRandom.urlsafe_base64(nil, false)
          end
        end

        def store_location
          authentication_routes = [:spree_signup_path, :spree_login_path, :spree_logout_path]
          disallowed_urls = []
          authentication_routes.each do |route|
            if respond_to?(route)
              #nodyna <send-2561> <SD MODERATE (array)>
              disallowed_urls << send(route)
            end
          end

          disallowed_urls.map!{ |url| url[/\/\w+$/] }
          unless disallowed_urls.include?(request.fullpath)
            session['spree_user_return_to'] = request.fullpath.gsub('//', '/')
          end
        end

        def try_spree_current_user
          if respond_to?(:spree_current_user)
            spree_current_user
          elsif respond_to?(:current_spree_user)
            current_spree_user
          else
            nil
          end
        end

        def redirect_unauthorized_access
          if try_spree_current_user
            flash[:error] = Spree.t(:authorization_failure)
            redirect_to '/unauthorized'
          else
            store_location
            if respond_to?(:spree_login_path)
              redirect_to spree_login_path
            else
              redirect_to spree.respond_to?(:root_path) ? spree.root_path : main_app.root_path
            end
          end
        end

      end
    end
  end
end
