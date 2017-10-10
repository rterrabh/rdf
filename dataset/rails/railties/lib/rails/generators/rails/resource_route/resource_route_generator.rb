module Rails
  module Generators
    class ResourceRouteGenerator < NamedBase # :nodoc:

      def add_resource_route
        return if options[:actions].present?

        regular_class_path.each_with_index do |namespace, index|
          write("namespace :#{namespace} do", index + 1)
        end

        write("resources :#{file_name.pluralize}", route_length + 1)

        regular_class_path.each_index do |index|
          write("end", route_length - index)
        end

        route route_string[2..-2]
      end

      private
        def route_string
          @route_string ||= ""
        end

        def write(str, indent)
          route_string << "#{"  " * indent}#{str}\n"
        end

        def route_length
          regular_class_path.length
        end
    end
  end
end
