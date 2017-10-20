require 'fileutils'
require 'yaml'
require 'active_support/core_ext/hash/keys'
require 'active_support/core_ext/object/blank'
require 'active_support/key_generator'
require 'active_support/message_verifier'
require 'rails/engine'

module Rails
  class Application < Engine
    autoload :Bootstrap,              'rails/application/bootstrap'
    autoload :Configuration,          'rails/application/configuration'
    autoload :DefaultMiddlewareStack, 'rails/application/default_middleware_stack'
    autoload :Finisher,               'rails/application/finisher'
    autoload :Railties,               'rails/engine/railties'
    autoload :RoutesReloader,         'rails/application/routes_reloader'

    class << self
      def inherited(base)
        super
        Rails.app_class = base
        add_lib_to_load_path!(find_root(base.called_from))
      end

      def instance
        super.run_load_hooks!
      end

      def create(initial_variable_values = {}, &block)
        new(initial_variable_values, &block).run_load_hooks!
      end

      def find_root(from)
        find_root_with_flag "config.ru", from, Dir.pwd
      end

      public :new
    end

    attr_accessor :assets, :sandbox
    alias_method :sandbox?, :sandbox
    attr_reader :reloaders

    delegate :default_url_options, :default_url_options=, to: :routes

    INITIAL_VARIABLES = [:config, :railties, :routes_reloader, :reloaders,
                         :routes, :helpers, :app_env_config, :secrets] # :nodoc:

    def initialize(initial_variable_values = {}, &block)
      super()
      @initialized       = false
      @reloaders         = []
      @routes_reloader   = nil
      @app_env_config    = nil
      @ordered_railties  = nil
      @railties          = nil
      @message_verifiers = {}
      @ran_load_hooks    = false

      @initial_variable_values = initial_variable_values
      @block = block
    end

    def initialized?
      @initialized
    end

    def run_load_hooks! # :nodoc:
      return self if @ran_load_hooks
      @ran_load_hooks = true
      ActiveSupport.run_load_hooks(:before_configuration, self)

      @initial_variable_values.each do |variable_name, value|
        if INITIAL_VARIABLES.include?(variable_name)
          #nodyna <instance_variable_set-1150> <IVS COMPLEX (array)>
          instance_variable_set("@#{variable_name}", value)
        end
      end

      #nodyna <instance_eval-1151> <IEV COMPLEX (block execution)>
      instance_eval(&@block) if @block
      self
    end

    def call(env)
      env["ORIGINAL_FULLPATH"] = build_original_fullpath(env)
      env["ORIGINAL_SCRIPT_NAME"] = env["SCRIPT_NAME"]
      super(env)
    end

    def reload_routes!
      routes_reloader.reload!
    end

    def key_generator
      @caching_key_generator ||=
        if secrets.secret_key_base
          key_generator = ActiveSupport::KeyGenerator.new(secrets.secret_key_base, iterations: 1000)
          ActiveSupport::CachingKeyGenerator.new(key_generator)
        else
          ActiveSupport::LegacyKeyGenerator.new(secrets.secret_token)
        end
    end

    def message_verifier(verifier_name)
      @message_verifiers[verifier_name] ||= begin
        secret = key_generator.generate_key(verifier_name.to_s)
        ActiveSupport::MessageVerifier.new(secret)
      end
    end

    def config_for(name)
      yaml = Pathname.new("#{paths["config"].existent.first}/#{name}.yml")

      if yaml.exist?
        require "erb"
        (YAML.load(ERB.new(yaml.read).result) || {})[Rails.env] || {}
      else
        raise "Could not load configuration. No such file - #{yaml}"
      end
    rescue Psych::SyntaxError => e
      raise "YAML syntax error occurred while parsing #{yaml}. " \
        "Please note that YAML must be consistently indented using spaces. Tabs are not allowed. " \
        "Error: #{e.message}"
    end

    def env_config
      @app_env_config ||= begin
        validate_secret_key_config!

        super.merge({
          "action_dispatch.parameter_filter" => config.filter_parameters,
          "action_dispatch.redirect_filter" => config.filter_redirect,
          "action_dispatch.secret_token" => secrets.secret_token,
          "action_dispatch.secret_key_base" => secrets.secret_key_base,
          "action_dispatch.show_exceptions" => config.action_dispatch.show_exceptions,
          "action_dispatch.show_detailed_exceptions" => config.consider_all_requests_local,
          "action_dispatch.logger" => Rails.logger,
          "action_dispatch.backtrace_cleaner" => Rails.backtrace_cleaner,
          "action_dispatch.key_generator" => key_generator,
          "action_dispatch.http_auth_salt" => config.action_dispatch.http_auth_salt,
          "action_dispatch.signed_cookie_salt" => config.action_dispatch.signed_cookie_salt,
          "action_dispatch.encrypted_cookie_salt" => config.action_dispatch.encrypted_cookie_salt,
          "action_dispatch.encrypted_signed_cookie_salt" => config.action_dispatch.encrypted_signed_cookie_salt,
          "action_dispatch.cookies_serializer" => config.action_dispatch.cookies_serializer,
          "action_dispatch.cookies_digest" => config.action_dispatch.cookies_digest
        })
      end
    end

    def rake_tasks(&block)
      self.class.rake_tasks(&block)
    end

    def initializer(name, opts={}, &block)
      self.class.initializer(name, opts, &block)
    end

    def runner(&blk)
      self.class.runner(&blk)
    end

    def console(&blk)
      self.class.console(&blk)
    end

    def generators(&blk)
      self.class.generators(&blk)
    end

    def isolate_namespace(mod)
      self.class.isolate_namespace(mod)
    end


    def self.add_lib_to_load_path!(root) #:nodoc:
      path = File.join root, 'lib'
      if File.exist?(path) && !$LOAD_PATH.include?(path)
        $LOAD_PATH.unshift(path)
      end
    end

    def require_environment! #:nodoc:
      environment = paths["config/environment"].existent.first
      require environment if environment
    end

    def routes_reloader #:nodoc:
      @routes_reloader ||= RoutesReloader.new
    end

    def watchable_args #:nodoc:
      files, dirs = config.watchable_files.dup, config.watchable_dirs.dup

      ActiveSupport::Dependencies.autoload_paths.each do |path|
        dirs[path.to_s] = [:rb]
      end

      [files, dirs]
    end

    def initialize!(group=:default) #:nodoc:
      raise "Application has been already initialized." if @initialized
      run_initializers(group, self)
      @initialized = true
      self
    end

    def initializers #:nodoc:
      Bootstrap.initializers_for(self) +
      railties_initializers(super) +
      Finisher.initializers_for(self)
    end

    def config #:nodoc:
      @config ||= Application::Configuration.new(self.class.find_root(self.class.called_from))
    end

    def config=(configuration) #:nodoc:
      @config = configuration
    end

    def secrets
      @secrets ||= begin
        secrets = ActiveSupport::OrderedOptions.new
        yaml = config.paths["config/secrets"].first
        if File.exist?(yaml)
          require "erb"
          all_secrets = YAML.load(ERB.new(IO.read(yaml)).result) || {}
          env_secrets = all_secrets[Rails.env]
          secrets.merge!(env_secrets.symbolize_keys) if env_secrets
        end

        secrets.secret_key_base ||= config.secret_key_base
        secrets.secret_token ||= config.secret_token

        secrets
      end
    end

    def secrets=(secrets) #:nodoc:
      @secrets = secrets
    end

    def to_app #:nodoc:
      self
    end

    def helpers_paths #:nodoc:
      config.helpers_paths
    end

    console do
      require "pp"
    end

    console do
      unless ::Kernel.private_method_defined?(:y)
        if RUBY_VERSION >= '2.0'
          require "psych/y"
        else
          module ::Kernel
            def y(*objects)
              puts ::Psych.dump_stream(*objects)
            end
            private :y
          end
        end
      end
    end

    def migration_railties # :nodoc:
      ordered_railties.flatten - [self]
    end

  protected

    alias :build_middleware_stack :app

    def run_tasks_blocks(app) #:nodoc:
      railties.each { |r| r.run_tasks_blocks(app) }
      super
      require "rails/tasks"
      task :environment do
        ActiveSupport.on_load(:before_initialize) { config.eager_load = false }

        require_environment!
      end
    end

    def run_generators_blocks(app) #:nodoc:
      railties.each { |r| r.run_generators_blocks(app) }
      super
    end

    def run_runner_blocks(app) #:nodoc:
      railties.each { |r| r.run_runner_blocks(app) }
      super
    end

    def run_console_blocks(app) #:nodoc:
      railties.each { |r| r.run_console_blocks(app) }
      super
    end

    def ordered_railties #:nodoc:
      @ordered_railties ||= begin
        order = config.railties_order.map do |railtie|
          if railtie == :main_app
            self
          elsif railtie.respond_to?(:instance)
            railtie.instance
          else
            railtie
          end
        end

        all = (railties - order)
        all.push(self)   unless (all + order).include?(self)
        order.push(:all) unless order.include?(:all)

        index = order.index(:all)
        order[index] = all
        order
      end
    end

    def railties_initializers(current) #:nodoc:
      initializers = []
      ordered_railties.reverse.flatten.each do |r|
        if r == self
          initializers += current
        else
          initializers += r.initializers
        end
      end
      initializers
    end

    def default_middleware_stack #:nodoc:
      default_stack = DefaultMiddlewareStack.new(self, config, paths)
      default_stack.build_stack
    end

    def build_original_fullpath(env) #:nodoc:
      path_info    = env["PATH_INFO"]
      query_string = env["QUERY_STRING"]
      script_name  = env["SCRIPT_NAME"]

      if query_string.present?
        "#{script_name}#{path_info}?#{query_string}"
      else
        "#{script_name}#{path_info}"
      end
    end

    def validate_secret_key_config! #:nodoc:
      if secrets.secret_key_base.blank?
        ActiveSupport::Deprecation.warn "You didn't set `secret_key_base`. " +
          "Read the upgrade documentation to learn more about this new config option."

        if secrets.secret_token.blank?
          raise "Missing `secret_token` and `secret_key_base` for '#{Rails.env}' environment, set these values in `config/secrets.yml`"
        end
      end
    end
  end
end
