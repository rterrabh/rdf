module ActiveAdmin
  class BaseController < ::InheritedResources::Base
    module Authorization
      include MethodOrProcHelper
      extend ActiveSupport::Concern

      ACTIONS_DICTIONARY = {
        index:   ActiveAdmin::Authorization::READ,
        show:    ActiveAdmin::Authorization::READ,
        new:     ActiveAdmin::Authorization::CREATE,
        create:  ActiveAdmin::Authorization::CREATE,
        edit:    ActiveAdmin::Authorization::UPDATE,
        update:  ActiveAdmin::Authorization::UPDATE,
        destroy: ActiveAdmin::Authorization::DESTROY
      }

      included do
        rescue_from ActiveAdmin::AccessDenied, with: :dispatch_active_admin_access_denied

        helper_method :authorized?
        helper_method :authorize!
      end

      protected

      def authorized?(action, subject = nil)
        active_admin_authorization.authorized?(action, subject)
      end


      def authorize!(action, subject = nil)
        unless authorized? action, subject
          raise ActiveAdmin::AccessDenied.new(current_active_admin_user,
                                              action,
                                              subject)
        end
      end

      def authorize_resource!(resource)
        permission = action_to_permission(params[:action])
        authorize! permission, resource
      end

      def active_admin_authorization
        @active_admin_authorization ||=
         active_admin_authorization_adapter.new active_admin_config, current_active_admin_user
      end

      def active_admin_authorization_adapter
        adapter = active_admin_namespace.authorization_adapter
        if adapter.is_a? String
          ActiveSupport::Dependencies.constantize adapter
        else
          adapter
        end
      end

      def action_to_permission(action)
        if action && action = action.to_sym
          Authorization::ACTIONS_DICTIONARY[action] || action
        end
      end

      def dispatch_active_admin_access_denied(exception)
        call_method_or_exec_proc active_admin_namespace.on_unauthorized_access, exception
      end

      def rescue_active_admin_access_denied(exception)
        error = exception.message

        respond_to do |format|
          format.html do
            flash[:error] = error
            redirect_backwards_or_to_root
          end

          format.csv  { render text:          error,           status: :unauthorized }
          format.json { render json: { error: error },         status: :unauthorized }
          format.xml  { render xml: "<error>#{error}</error>", status: :unauthorized }
        end
      end

      def redirect_backwards_or_to_root
        if request.headers.key? "HTTP_REFERER"
          redirect_to :back
        else
          controller, action = active_admin_namespace.root_to.split '#'
          redirect_to controller: controller, action: action
        end
      end

    end
  end
end
