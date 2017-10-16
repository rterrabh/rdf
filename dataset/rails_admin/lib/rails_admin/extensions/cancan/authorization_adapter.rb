module RailsAdmin
  module Extensions
    module CanCan
      class AuthorizationAdapter
        def initialize(controller, ability = ::Ability)
          @controller = controller
          #nodyna <instance_variable_set-1344> <IVS COMPLEX (private access)>
          @controller.instance_variable_set '@ability', ability
          @controller.extend ControllerExtension
          @controller.current_ability.authorize! :access, :rails_admin
        end

        def authorize(action, abstract_model = nil, model_object = nil)
          @controller.current_ability.authorize!(action, model_object || abstract_model && abstract_model.model) if action
        end

        def authorized?(action, abstract_model = nil, model_object = nil)
          @controller.current_ability.can?(action, model_object || abstract_model && abstract_model.model) if action
        end

        def query(action, abstract_model)
          abstract_model.model.accessible_by(@controller.current_ability, action)
        end

        def attributes_for(action, abstract_model)
          @controller.current_ability.attributes_for(action, abstract_model && abstract_model.model)
        end

        module ControllerExtension
          def current_ability
            @current_ability ||= @ability.new(_current_user)
          end
        end
      end
    end
  end
end
