require 'rails/railtie'
require 'rails/engine/railties'
require 'active_support/core_ext/module/delegation'
require 'pathname'

module Rails
  class Engine < Railtie
    autoload :Configuration, "rails/engine/configuration"

    class << self
      attr_accessor :called_from, :isolated

      alias :isolated? :isolated
      alias :engine_name :railtie_name

      delegate :eager_load!, to: :instance

      def inherited(base)
        unless base.abstract_railtie?
          Rails::Railtie::Configuration.eager_load_namespaces << base

          base.called_from = begin
            call_stack = if Kernel.respond_to?(:caller_locations)
              caller_locations.map { |l| l.absolute_path || l.path }
            else
              caller.map { |p| p.sub(/:\d+.*/, '') }
            end

            File.dirname(call_stack.detect { |p| p !~ %r[railties[\w.-]*/lib/rails|rack[\w.-]*/lib/rack] })
          end
        end

        super
      end

      def find_root(from)
        find_root_with_flag "lib", from
      end

      def endpoint(endpoint = nil)
        @endpoint ||= nil
        @endpoint = endpoint if endpoint
        @endpoint
      end

      def isolate_namespace(mod)
        engine_name(generate_railtie_name(mod.name))

        self.routes.default_scope = { module: ActiveSupport::Inflector.underscore(mod.name) }
        self.isolated = true

        unless mod.respond_to?(:railtie_namespace)
          name, railtie = engine_name, self

          #nodyna <instance_eval-1169> <IEV COMPLEX (method definition)>
          mod.singleton_class.instance_eval do
            #nodyna <define_method-1170> <DM MODERATE (events)>
            define_method(:railtie_namespace) { railtie }

            unless mod.respond_to?(:table_name_prefix)
              #nodyna <define_method-1171> <DM COMPLEX (events)>
              define_method(:table_name_prefix) { "#{name}_" }
            end

            unless mod.respond_to?(:use_relative_model_naming?)
              #nodyna <class_eval-1172> <not yet classified>
              class_eval "def use_relative_model_naming?; true; end", __FILE__, __LINE__
            end

            unless mod.respond_to?(:railtie_helpers_paths)
              #nodyna <define_method-1173> <DM MODERATE (events)>
              define_method(:railtie_helpers_paths) { railtie.helpers_paths }
            end

            unless mod.respond_to?(:railtie_routes_url_helpers)
              #nodyna <define_method-1174> <DM MODERATE (events)>
              define_method(:railtie_routes_url_helpers) {|include_path_helpers = true| railtie.routes.url_helpers(include_path_helpers) }
            end
          end
        end
      end

      def find(path)
        expanded_path = File.expand_path path
        Rails::Engine.subclasses.each do |klass|
          engine = klass.instance
          return engine if File.expand_path(engine.root) == expanded_path
        end
        nil
      end
    end

    delegate :middleware, :root, :paths, to: :config
    delegate :engine_name, :isolated?, to: :class

    def initialize
      @_all_autoload_paths = nil
      @_all_load_paths     = nil
      @app                 = nil
      @config              = nil
      @env_config          = nil
      @helpers             = nil
      @routes              = nil
      super
    end

    def load_console(app=self)
      require "rails/console/app"
      require "rails/console/helpers"
      run_console_blocks(app)
      self
    end

    def load_runner(app=self)
      run_runner_blocks(app)
      self
    end

    def load_tasks(app=self)
      require "rake"
      run_tasks_blocks(app)
      self
    end

    def load_generators(app=self)
      require "rails/generators"
      run_generators_blocks(app)
      Rails::Generators.configure!(app.config.generators)
      self
    end

    def eager_load!
      config.eager_load_paths.each do |load_path|
        matcher = /\A#{Regexp.escape(load_path.to_s)}\/(.*)\.rb\Z/
        Dir.glob("#{load_path}/**/*.rb").sort.each do |file|
          require_dependency file.sub(matcher, '\1')
        end
      end
    end

    def railties
      @railties ||= Railties.new
    end

    def helpers
      @helpers ||= begin
        helpers = Module.new
        all = ActionController::Base.all_helpers_from_path(helpers_paths)
        ActionController::Base.modules_for_helpers(all).each do |mod|
          #nodyna <send-1175> <SD TRIVIAL (public methods)>
          helpers.send(:include, mod)
        end
        helpers
      end
    end

    def helpers_paths
      paths["app/helpers"].existent
    end

    def app
      @app ||= begin
        config.middleware = config.middleware.merge_into(default_middleware_stack)
        config.middleware.build(endpoint)
      end
    end

    def endpoint
      self.class.endpoint || routes
    end

    def call(env)
      env.merge!(env_config)
      if env['SCRIPT_NAME']
        env["ROUTES_#{routes.object_id}_SCRIPT_NAME"] = env['SCRIPT_NAME'].dup
      end
      app.call(env)
    end

    def env_config
      @env_config ||= {
        'action_dispatch.routes' => routes
      }
    end

    def routes
      @routes ||= ActionDispatch::Routing::RouteSet.new
      @routes.append(&Proc.new) if block_given?
      @routes
    end

    def config
      @config ||= Engine::Configuration.new(self.class.find_root(self.class.called_from))
    end

    def load_seed
      seed_file = paths["db/seeds.rb"].existent.first
      load(seed_file) if seed_file
    end

    initializer :set_load_path, before: :bootstrap_hook do
      _all_load_paths.reverse_each do |path|
        $LOAD_PATH.unshift(path) if File.directory?(path)
      end
      $LOAD_PATH.uniq!
    end

    initializer :set_autoload_paths, before: :bootstrap_hook do
      ActiveSupport::Dependencies.autoload_paths.unshift(*_all_autoload_paths)
      ActiveSupport::Dependencies.autoload_once_paths.unshift(*_all_autoload_once_paths)

      config.autoload_paths.freeze
      config.eager_load_paths.freeze
      config.autoload_once_paths.freeze
    end

    initializer :add_routing_paths do |app|
      routing_paths = self.paths["config/routes.rb"].existent

      if routes? || routing_paths.any?
        app.routes_reloader.paths.unshift(*routing_paths)
        app.routes_reloader.route_sets << routes
      end
    end

    initializer :add_locales do
      config.i18n.railties_load_path.concat(paths["config/locales"].existent)
    end

    initializer :add_view_paths do
      views = paths["app/views"].existent
      unless views.empty?
        ActiveSupport.on_load(:action_controller){ prepend_view_path(views) if respond_to?(:prepend_view_path) }
        ActiveSupport.on_load(:action_mailer){ prepend_view_path(views) }
      end
    end

    initializer :load_environment_config, before: :load_environment_hook, group: :all do
      paths["config/environments"].existent.each do |environment|
        require environment
      end
    end

    initializer :append_assets_path, group: :all do |app|
      app.config.assets.paths.unshift(*paths["vendor/assets"].existent_directories)
      app.config.assets.paths.unshift(*paths["lib/assets"].existent_directories)
      app.config.assets.paths.unshift(*paths["app/assets"].existent_directories)
    end

    initializer :prepend_helpers_path do |app|
      if !isolated? || (app == self)
        app.config.helpers_paths.unshift(*paths["app/helpers"].existent)
      end
    end

    initializer :load_config_initializers do
      config.paths["config/initializers"].existent.sort.each do |initializer|
        load_config_initializer(initializer)
      end
    end

    initializer :engines_blank_point do
    end

    rake_tasks do
      next if self.is_a?(Rails::Application)
      next unless has_migrations?

      namespace railtie_name do
        namespace :install do
          desc "Copy migrations from #{railtie_name} to application"
          task :migrations do
            ENV["FROM"] = railtie_name
            if Rake::Task.task_defined?("railties:install:migrations")
              Rake::Task["railties:install:migrations"].invoke
            else
              Rake::Task["app:railties:install:migrations"].invoke
            end
          end
        end
      end
    end

    def routes? #:nodoc:
      @routes
    end

    protected

    def load_config_initializer(initializer)
      ActiveSupport::Notifications.instrument('load_config_initializer.railties', initializer: initializer) do
        load(initializer)
      end
    end

    def run_tasks_blocks(*) #:nodoc:
      super
      paths["lib/tasks"].existent.sort.each { |ext| load(ext) }
    end

    def has_migrations? #:nodoc:
      paths["db/migrate"].existent.any?
    end

    def self.find_root_with_flag(flag, root_path, default=nil) #:nodoc:

      while root_path && File.directory?(root_path) && !File.exist?("#{root_path}/#{flag}")
        parent = File.dirname(root_path)
        root_path = parent != root_path && parent
      end

      root = File.exist?("#{root_path}/#{flag}") ? root_path : default
      raise "Could not find root path for #{self}" unless root

      Pathname.new File.realpath root
    end

    def default_middleware_stack #:nodoc:
      ActionDispatch::MiddlewareStack.new
    end

    def _all_autoload_once_paths #:nodoc:
      config.autoload_once_paths
    end

    def _all_autoload_paths #:nodoc:
      @_all_autoload_paths ||= (config.autoload_paths + config.eager_load_paths + config.autoload_once_paths).uniq
    end

    def _all_load_paths #:nodoc:
      @_all_load_paths ||= (config.paths.load_paths + _all_autoload_paths).uniq
    end
  end
end
