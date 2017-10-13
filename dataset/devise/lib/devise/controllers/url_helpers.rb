module Devise
  module Controllers
    module UrlHelpers
      def self.remove_helpers!
        self.instance_methods.map(&:to_s).grep(/_(url|path)$/).each do |method|
          remove_method method
        end
      end

      def self.generate_helpers!(routes=nil)
        routes ||= begin
          mappings = Devise.mappings.values.map(&:used_helpers).flatten.uniq
          Devise::URL_HELPERS.slice(*mappings)
        end

        routes.each do |module_name, actions|
          [:path, :url].each do |path_or_url|
            actions.each do |action|
              action = action ? "#{action}_" : ""
              method = "#{action}#{module_name}_#{path_or_url}"

              #nodyna <class_eval-2767> <CE COMPLEX (define methods)>
              class_eval <<-URL_HELPERS, __FILE__, __LINE__ + 1
                def #{method}(resource_or_scope, *args)
                  scope = Devise::Mapping.find_scope!(resource_or_scope)
                  router_name = Devise.mappings[scope].router_name
                  #nodyna <send-2768> <SD COMPLEX (change-prone variable)>
                  context = router_name ? send(router_name) : _devise_route_context
                  #nodyna <send-2769> <SD COMPLEX (change-prone variable)>
                  context.send("#{action}\#{scope}_#{module_name}_#{path_or_url}", *args)
                end
              URL_HELPERS
            end
          end
        end
      end

      generate_helpers!(Devise::URL_HELPERS)

      private

      def _devise_route_context
        #nodyna <send-2770> <SD COMPLEX (change-prone variable)>
        @_devise_route_context ||= send(Devise.available_router_name)
      end
    end
  end
end
