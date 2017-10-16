module CanCan

  module ControllerAdditions
    module ClassMethods
      def load_and_authorize_resource(*args)
        cancan_resource_class.add_before_filter(self, :load_and_authorize_resource, *args)
      end

      def load_resource(*args)
        cancan_resource_class.add_before_filter(self, :load_resource, *args)
      end

      def authorize_resource(*args)
        cancan_resource_class.add_before_filter(self, :authorize_resource, *args)
      end

      def skip_load_and_authorize_resource(*args)
        skip_load_resource(*args)
        skip_authorize_resource(*args)
      end

      def skip_load_resource(*args)
        options = args.extract_options!
        name = args.first
        cancan_skipper[:load][name] = options
      end

      def skip_authorize_resource(*args)
        options = args.extract_options!
        name = args.first
        cancan_skipper[:authorize][name] = options
      end

      def check_authorization(options = {})
        self.after_filter(options.slice(:only, :except)) do |controller|
          next if controller.instance_variable_defined?(:@_authorized)
          #nodyna <send-2590> <SD COMPLEX (change-prone variable)>
          next if options[:if] && !controller.send(options[:if])
          #nodyna <send-2591> <SD COMPLEX (change-prone variable)>
          next if options[:unless] && controller.send(options[:unless])
          raise AuthorizationNotPerformed, "This action failed the check_authorization because it does not authorize_resource. Add skip_authorization_check to bypass this check."
        end
      end

      def skip_authorization_check(*args)
        self.before_filter(*args) do |controller|
          #nodyna <instance_variable_set-2592> <IVS MODERATE (private access)>
          controller.instance_variable_set(:@_authorized, true)
        end
      end

      def skip_authorization(*args)
        raise ImplementationRemoved, "The CanCan skip_authorization method has been renamed to skip_authorization_check. Please update your code."
      end

      def cancan_resource_class
        if ancestors.map(&:to_s).include? "InheritedResources::Actions"
          InheritedResource
        else
          ControllerResource
        end
      end

      def cancan_skipper
        @_cancan_skipper ||= {:authorize => {}, :load => {}}
      end
    end

    def self.included(base)
      base.extend ClassMethods
      base.helper_method :can?, :cannot?, :current_ability
    end

    def authorize!(*args)
      @_authorized = true
      current_ability.authorize!(*args)
    end

    def unauthorized!(message = nil)
      raise ImplementationRemoved, "The unauthorized! method has been removed from CanCan, use authorize! instead."
    end

    def current_ability
      @current_ability ||= ::Ability.new(current_user)
    end

    def can?(*args)
      current_ability.can?(*args)
    end

    def cannot?(*args)
      current_ability.cannot?(*args)
    end
  end
end

if defined? ActionController::Base
  #nodyna <class_eval-2593> <CE TRIVIAL (block execution)>
  ActionController::Base.class_eval do
    include CanCan::ControllerAdditions
  end
end
