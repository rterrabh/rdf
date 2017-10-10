require 'active_admin/router'
require 'active_admin/helpers/settings'

module ActiveAdmin
  class Application
    include Settings
    include Settings::Inheritance

    settings_inherited_by Namespace

    setting :default_namespace, :admin

    attr_reader :namespaces
    def initialize
      @namespaces = Namespace::Store.new
    end

    setting :load_paths, [File.expand_path('app/admin', Rails.root)]

    inheritable_setting :default_per_page, 30

    inheritable_setting :site_title, ""

    inheritable_setting :site_title_link, ""

    inheritable_setting :site_title_image, ""

    inheritable_setting :favicon, false

    inheritable_setting :view_factory, ActiveAdmin::ViewFactory.new

    inheritable_setting :current_user_method, false

    inheritable_setting :authentication_method, false

    inheritable_setting :logout_link_path, :destroy_admin_user_session_path

    inheritable_setting :logout_link_method, :get

    inheritable_setting :batch_actions, false

    inheritable_setting :filters, true

    inheritable_setting :root_to, 'dashboard#index'

    inheritable_setting :root_to_options, {}

    inheritable_setting :breadcrumb, true

    inheritable_setting :csv_options, { col_sep: ',', byte_order_mark: "\xEF\xBB\xBF" }

    inheritable_setting :download_links, true

    inheritable_setting :authorization_adapter, ActiveAdmin::AuthorizationAdapter

    inheritable_setting :on_unauthorized_access, :rescue_active_admin_access_denied

    inheritable_setting :unsupported_browser_matcher, /MSIE [1-8]\.0/

    inheritable_setting :permitted_params, [
      :utf8, :_method, :authenticity_token, :commit, :id
    ]

    inheritable_setting :flash_keys_to_except, ['timedout']

    setting :display_name_methods, [ :display_name,
                                      :full_name,
                                      :name,
                                      :username,
                                      :login,
                                      :title,
                                      :email,
                                      :to_s ]


    def allow_comments=(*)
      raise "`config.allow_comments` is no longer provided in ActiveAdmin 1.x. Use `config.comments` instead."
    end

    include AssetRegistration

    BeforeLoadEvent = 'active_admin.application.before_load'.freeze
    AfterLoadEvent  = 'active_admin.application.after_load'.freeze

    def setup!
      register_default_assets
    end

    def prepare!
      remove_active_admin_load_paths_from_rails_autoload_and_eager_load
      attach_reloader
    end

    def register(resource, options = {}, &block)
      ns = options.fetch(:namespace){ default_namespace }
      namespace(ns).register resource, options, &block
    end

    def namespace(name)
      name ||= :root

      namespace = namespaces[name] ||= begin
        namespace = Namespace.new(self, name)
        ActiveAdmin::Event.dispatch ActiveAdmin::Namespace::RegisterEvent, namespace
        namespace
      end

      yield(namespace) if block_given?

      namespace
    end

    def register_page(name, options = {}, &block)
      ns = options.fetch(:namespace){ default_namespace }
      namespace(ns).register_page name, options, &block
    end

    def loaded?
      @@loaded ||= false
    end

    def unload!
      namespaces.each &:unload!
      @@loaded = false
    end

    def load!
      unless loaded?
        ActiveAdmin::Event.dispatch BeforeLoadEvent, self # before_load hook
        files.each{ |file| load file }                    # load files
        namespace(default_namespace)                      # init AA resources
        ActiveAdmin::Event.dispatch AfterLoadEvent, self  # after_load hook
        @@loaded = true
      end
    end

    def load(file)
      DatabaseHitDuringLoad.capture{ super }
    end

    def files
      load_paths.flatten.compact.uniq.flat_map{ |path| Dir["#{path}/**/*.rb"] }
    end

    def router
      @router ||= Router.new(self)
    end

    def routes(rails_router)
      load!
      router.apply(rails_router)
    end

    %w(before_filter skip_before_filter after_filter skip_after_filter around_filter skip_filter).each do |name|
      #nodyna <define_method-70> <DM MODERATE (events)>
      define_method name do |*args, &block|
        controllers_for_filters.each do |controller|
          #nodyna <send-71> <SD MODERATE (change-prone variables)>
          controller.public_send name, *args, &block
        end
      end
    end

    def controllers_for_filters
      controllers = [BaseController]
      controllers.push *Devise.controllers_for_filters if Dependency.devise?
      controllers
    end

  private

    def register_default_assets
      register_stylesheet 'active_admin.css',       media: 'screen'
      register_stylesheet 'active_admin/print.css', media: 'print'

      register_javascript 'active_admin.js'
    end

    def remove_active_admin_load_paths_from_rails_autoload_and_eager_load
      ActiveSupport::Dependencies.autoload_paths -= load_paths
      Rails.application.config.eager_load_paths  -= load_paths
    end

    def attach_reloader
      load_paths.each do |path|
        ActiveAdmin::Engine.config.watchable_dirs[path] = [:rb]
      end

      Rails.application.config.after_initialize do
        ActionDispatch::Reloader.to_prepare do
          ActiveAdmin.application.unload!
          Rails.application.reload_routes!
        end
      end
    end
  end
end
