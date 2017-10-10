module ActiveAdmin
  class ResourceController < BaseController
    module ResourceClassMethods

      def override_resource_class_methods!
        class_exec do
          def self.resource_class=(klass); end

          def self.resource_class
            @active_admin_config ? @active_admin_config.resource_class : nil
          end

          def resource_class
            self.class.resource_class
          end
        end
      end

    end
  end
end
