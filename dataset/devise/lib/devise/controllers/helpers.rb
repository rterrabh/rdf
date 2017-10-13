module Devise
  module Controllers
    module Helpers
      extend ActiveSupport::Concern
      include Devise::Controllers::SignInOut
      include Devise::Controllers::StoreLocation

      included do
        helper_method :warden, :signed_in?, :devise_controller?
      end

      module ClassMethods
        def devise_group(group_name, opts={})
          mappings = "[#{ opts[:contains].map { |m| ":#{m}" }.join(',') }]"

          #nodyna <class_eval-2772> <CE MODERATE (define methods)>
          class_eval <<-METHODS, __FILE__, __LINE__ + 1
            def authenticate_#{group_name}!(favourite=nil, opts={})
              unless #{group_name}_signed_in?
                mappings = #{mappings}
                mappings.unshift mappings.delete(favourite.to_sym) if favourite
                mappings.each do |mapping|
                  opts[:scope] = mapping
                  warden.authenticate!(opts) if !devise_controller? || opts.delete(:force)
                end
              end
            end

            def #{group_name}_signed_in?
                warden.authenticate?(scope: mapping)
              end
            end

            def current_#{group_name}(favourite=nil)
              mappings = #{mappings}
              mappings.unshift mappings.delete(favourite.to_sym) if favourite
              mappings.each do |mapping|
                current = warden.authenticate(scope: mapping)
                return current if current
              end
              nil
            end

            def current_#{group_name.to_s.pluralize}
                warden.authenticate(scope: mapping)
              end.compact
            end

            helper_method "current_#{group_name}", "current_#{group_name.to_s.pluralize}", "#{group_name}_signed_in?"
          METHODS
        end

        def log_process_action(payload)
          payload[:status] ||= 401 unless payload[:exception]
          super
        end
      end

      def self.define_helpers(mapping) #:nodoc:
        mapping = mapping.name

        #nodyna <class_eval-2773> <CE MODERATE (define methods)>
        class_eval <<-METHODS, __FILE__, __LINE__ + 1
          def authenticate_#{mapping}!(opts={})
            opts[:scope] = :#{mapping}
            warden.authenticate!(opts) if !devise_controller? || opts.delete(:force)
          end

          def #{mapping}_signed_in?
            !!current_#{mapping}
          end

          def current_#{mapping}
            @current_#{mapping} ||= warden.authenticate(scope: :#{mapping})
          end

          def #{mapping}_session
            current_#{mapping} && warden.session(:#{mapping})
          end
        METHODS

        ActiveSupport.on_load(:action_controller) do
          helper_method "current_#{mapping}", "#{mapping}_signed_in?", "#{mapping}_session"
        end
      end

      def warden
        request.env['warden']
      end

      def devise_controller?
        is_a?(::DeviseController)
      end

      def devise_parameter_sanitizer
        @devise_parameter_sanitizer ||= if defined?(ActionController::StrongParameters)
          Devise::ParameterSanitizer.new(resource_class, resource_name, params)
        else
          Devise::BaseSanitizer.new(resource_class, resource_name, params)
        end
      end

      def allow_params_authentication!
        request.env["devise.allow_params_authentication"] = true
      end

      def signed_in_root_path(resource_or_scope)
        scope = Devise::Mapping.find_scope!(resource_or_scope)
        router_name = Devise.mappings[scope].router_name

        home_path = "#{scope}_root_path"

        #nodyna <send-2774> <SD COMPLEX (change-prone variable)>
        context = router_name ? send(router_name) : self

        if context.respond_to?(home_path, true)
          #nodyna <send-2775> <SD COMPLEX (change-prone variable)>
          context.send(home_path)
        elsif context.respond_to?(:root_path)
          context.root_path
        elsif respond_to?(:root_path)
          root_path
        else
          "/"
        end
      end

      def after_sign_in_path_for(resource_or_scope)
        stored_location_for(resource_or_scope) || signed_in_root_path(resource_or_scope)
      end

      def after_sign_out_path_for(resource_or_scope)
        scope = Devise::Mapping.find_scope!(resource_or_scope)
        router_name = Devise.mappings[scope].router_name
        #nodyna <send-2776> <SD COMPLEX (change-prone variable)>
        context = router_name ? send(router_name) : self
        context.respond_to?(:root_path) ? context.root_path : "/"
      end

      def sign_in_and_redirect(resource_or_scope, *args)
        options  = args.extract_options!
        scope    = Devise::Mapping.find_scope!(resource_or_scope)
        resource = args.last || resource_or_scope
        sign_in(scope, resource, options)
        redirect_to after_sign_in_path_for(resource)
      end

      def sign_out_and_redirect(resource_or_scope)
        scope = Devise::Mapping.find_scope!(resource_or_scope)
        redirect_path = after_sign_out_path_for(scope)
        Devise.sign_out_all_scopes ? sign_out : sign_out(scope)
        redirect_to redirect_path
      end

      def handle_unverified_request
        super # call the default behaviour which resets/nullifies/raises
        request.env["devise.skip_storage"] = true
        sign_out_all_scopes(false)
      end

      def request_format
        @request_format ||= request.format.try(:ref)
      end

      def is_navigational_format?
        Devise.navigational_formats.include?(request_format)
      end

      def is_flashing_format?
        is_navigational_format?
      end

      private

      def expire_session_data_after_sign_in!
        ActiveSupport::Deprecation.warn "expire_session_data_after_sign_in! is deprecated " \
          "in favor of expire_data_after_sign_in!"
        expire_data_after_sign_in!
      end

      def expire_data_after_sign_out!
        #nodyna <instance_variable_set-2777> <IVS COMPLEX (change-prone variable)>
        Devise.mappings.each { |_,m| instance_variable_set("@current_#{m.name}", nil) }
        super
      end
    end
  end
end
