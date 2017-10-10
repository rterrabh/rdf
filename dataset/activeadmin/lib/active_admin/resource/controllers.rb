module ActiveAdmin
  class Resource
    module Controllers
      delegate :resources_configuration, to: :controller

      def controller_name
        [namespace.module_name, resource_name.plural.camelize + "Controller"].compact.join('::')
      end

      def controller
        @controller ||= controller_name.constantize
      end

    end
  end
end
