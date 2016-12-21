module AbstractController
  module Railties
    module RoutesHelpers
      def self.with(routes, include_path_helpers = true)
        Module.new do
          #nodyna <ID:define_method-9> <define_method MEDIUM ex2>
          define_method(:inherited) do |klass|
            super(klass)
            if namespace = klass.parents.detect { |m| m.respond_to?(:railtie_routes_url_helpers) }
              #nodyna <ID:send-71> <send VERY LOW ex1>
              klass.send(:include, namespace.railtie_routes_url_helpers(include_path_helpers))
            else
              #nodyna <ID:send-72> <send VERY LOW ex1>
              klass.send(:include, routes.url_helpers(include_path_helpers))
            end
          end
        end
      end
    end
  end
end
