ActiveAdmin::Dependency.pundit!

require 'pundit'

ActiveAdmin::Application.inheritable_setting :pundit_default_policy, nil

module ActiveAdmin

  class PunditAdapter < AuthorizationAdapter

    def authorized?(action, subject = nil)
      policy = retrieve_policy(subject)
      action = format_action(action, subject)

      #nodyna <send-39> <SD MODERATE (change-prone variables)>
      policy.respond_to?(action) && policy.public_send(action)
    end

    def scope_collection(collection, action = Auth::READ)
      Pundit.policy_scope!(user, collection)
    rescue Pundit::NotDefinedError => e
      if default_policy_class && default_policy_class.const_defined?(:Scope)
        default_policy_class::Scope.new(user, collection).resolve
      else
        raise e
      end
    end

    def retrieve_policy(subject)
      case subject
      when nil   then Pundit.policy!(user, resource)
      when Class then Pundit.policy!(user, subject.new)
      else Pundit.policy!(user, subject)
      end
    rescue Pundit::NotDefinedError => e
      if default_policy_class
        default_policy(user, subject)
      else
        raise e
      end
    end

    def format_action(action, subject)
      case action
      when Auth::CREATE  then :create?
      when Auth::UPDATE  then :update?
      when Auth::READ    then subject.is_a?(Class) ? :index? : :show?
      when Auth::DESTROY then subject.is_a?(Class) ? :destroy_all? : :destroy?
      else "#{action}?"
      end
    end

    private

    def default_policy_class
      ActiveAdmin.application.pundit_default_policy && ActiveAdmin.application.pundit_default_policy.constantize
    end

    def default_policy(user, subject)
      default_policy_class.new(user, subject)
    end

  end

end
