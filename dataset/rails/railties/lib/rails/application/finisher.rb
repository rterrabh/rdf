module Rails
  class Application
    module Finisher
      include Initializable

      initializer :add_generator_templates do
        config.generators.templates.unshift(*paths["lib/templates"].existent)
      end

      initializer :ensure_autoload_once_paths_as_subset do
        extra = ActiveSupport::Dependencies.autoload_once_paths -
                ActiveSupport::Dependencies.autoload_paths

        unless extra.empty?
          abort <<-end_error
            autoload_once_paths must be a subset of the autoload_paths.
            Extra items in autoload_once_paths: #{extra * ','}
          end_error
        end
      end

      initializer :add_builtin_route do |app|
        if Rails.env.development?
          app.routes.append do
            get '/rails/info/properties' => "rails/info#properties"
            get '/rails/info/routes'     => "rails/info#routes"
            get '/rails/info'            => "rails/info#index"
            get '/'                      => "rails/welcome#index"
          end
        end
      end

      initializer :build_middleware_stack do
        build_middleware_stack
      end

      initializer :define_main_app_helper do |app|
        app.routes.define_mounted_helper(:main_app)
      end

      initializer :add_to_prepare_blocks do
        config.to_prepare_blocks.each do |block|
          ActionDispatch::Reloader.to_prepare(&block)
        end
      end

      initializer :run_prepare_callbacks do
        ActionDispatch::Reloader.prepare!
      end

      initializer :eager_load! do
        if config.eager_load
          ActiveSupport.run_load_hooks(:before_eager_load, self)
          config.eager_load_namespaces.each(&:eager_load!)
        end
      end

      initializer :finisher_hook do
        ActiveSupport.run_load_hooks(:after_initialize, self)
      end

      initializer :set_routes_reloader_hook do
        reloader = routes_reloader
        reloader.execute_if_updated
        self.reloaders << reloader
        ActionDispatch::Reloader.to_prepare do
          reloader.execute
        end
      end

      initializer :set_clear_dependencies_hook, group: :all do
        callback = lambda do
          ActiveSupport::DescendantsTracker.clear
          ActiveSupport::Dependencies.clear
        end

        if config.reload_classes_only_on_change
          reloader = config.file_watcher.new(*watchable_args, &callback)
          self.reloaders << reloader

          ActionDispatch::Reloader.to_prepare(prepend: true) do
            reloader.execute
          end
        else
          ActionDispatch::Reloader.to_cleanup(&callback)
        end
      end
    end
  end
end
