module Rails
  module Generators
    class ControllerGenerator < NamedBase # :nodoc:
      argument :actions, type: :array, default: [], banner: "action action"
      class_option :skip_routes, type: :boolean, desc: "Don't add routes to config/routes.rb."

      check_class_collision suffix: "Controller"

      def create_controller_files
        template 'controller.rb', File.join('app/controllers', class_path, "#{file_name}_controller.rb")
      end

      def add_routes
        unless options[:skip_routes]
          actions.reverse_each do |action|
            route generate_routing_code(action)
          end
        end
      end

      hook_for :template_engine, :test_framework, :helper, :assets

      private

        def generate_routing_code(action)
          depth = regular_class_path.length
          namespace_ladder = regular_class_path.each_with_index.map do |ns, i|
            indent("namespace :#{ns} do\n", i * 2)
          end.join

          route = indent(%{get '#{file_name}/#{action}'\n}, depth * 2)

          end_ladder = (1..depth).reverse_each.map do |i|
            indent("end\n", i * 2)
          end.join

          namespace_ladder + route + end_ladder
        end
    end
  end
end
