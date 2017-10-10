module AbstractController
  module Railties
    module RoutesHelpers
      def self.with(routes, include_path_helpers = true)
        Module.new do
          #nodyna <define_method-1312> <DM MODERATE (events)>
          define_method(:inherited) do |klass|
            super(klass)
            if namespace = klass.parents.detect { |m| m.respond_to?(:railtie_routes_url_helpers) }
              #nodyna <send-1313> <SD TRIVIAL (public methods)>
              klass.send(:include, namespace.railtie_routes_url_helpers(include_path_helpers))
            else
              #nodyna <send-1314> <SD TRIVIAL (public methods)>
              klass.send(:include, routes.url_helpers(include_path_helpers))
            end
          end
        end
      end
    end
  end
end
