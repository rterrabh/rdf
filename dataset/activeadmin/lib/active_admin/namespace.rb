require 'active_admin/resource_collection'

module ActiveAdmin

  class Namespace
    RegisterEvent = 'active_admin.namespace.register'.freeze

    attr_reader :application, :resources, :name, :menus

    def initialize(application, name)
      @application = application
      @name = name.to_s.underscore.to_sym
      @resources = ResourceCollection.new
      register_module unless root?
      build_menu_collection
    end

    def register(resource_class, options = {}, &block)
      config = find_or_build_resource(resource_class, options)

      register_resource_controller(config)
      parse_registration_block(config, resource_class, &block) if block_given?
      reset_menu!

      ActiveAdmin::Event.dispatch ActiveAdmin::Resource::RegisterEvent, config

      config
    end

    def register_page(name, options = {}, &block)
      config = build_page(name, options)

      register_page_controller(config)
      parse_page_registration_block(config, &block) if block_given?
      reset_menu!

      config
    end

    def root?
      name == :root
    end

    def module_name
      return nil if root?
      @module_name ||= name.to_s.camelize
    end

    def unload!
      unload_resources!
      reset_menu!
    end

    def resource_for(klass)

      resources[klass]
    end

    def read_default_setting(name)
      #nodyna <send-15> <SD COMPLEX (change-prone variables)>
      application.public_send name
    end

    def fetch_menu(name)
      @menus.fetch(name)
    end

    def reset_menu!
      @menus.clear!
    end

    def build_menu(name = DEFAULT_MENU, &block)
      @menus.before_build do |menus|
        menus.menu name do |menu|
          block.call(menu)
        end
      end
    end

    def add_logout_button_to_menu(menu, priority = 20, html_options = {})
      if logout_link_path
        html_options = html_options.reverse_merge(method: logout_link_method || :get)
        menu.add id: 'logout', priority: priority, html_options: html_options,
          label: ->{ I18n.t 'active_admin.logout' },
          url:   ->{ render_or_call_method_or_proc_on self, active_admin_namespace.logout_link_path },
          if:    :current_active_admin_user?
      end
    end

    def add_current_user_to_menu(menu, priority = 10, html_options = {})
      if current_user_method
        menu.add id: 'current_user', priority: priority, html_options: html_options,
          label: -> { display_name current_active_admin_user },
          url:   -> { auto_url_for(current_active_admin_user) },
          if:    :current_active_admin_user?
      end
    end

    protected

    def build_menu_collection
      @menus = MenuCollection.new

      @menus.on_build do |menus|
        build_default_utility_nav

        resources.each do |resource|
          resource.add_to_menu(@menus)
        end
      end
    end

    def build_default_utility_nav
      return if @menus.exists? :utility_navigation
      @menus.menu :utility_navigation do |menu|
        add_current_user_to_menu menu
        add_logout_button_to_menu menu
      end
    end

    def find_or_build_resource(resource_class, options)
      resources.add Resource.new(self, resource_class, options)
    end

    def build_page(name, options)
      resources.add Page.new(self, name, options)
    end

    def register_page_controller(config)
      #nodyna <eval-16> <EV COMPLEX (class definition)>
      eval "class ::#{config.controller_name} < ActiveAdmin::PageController; end"
      config.controller.active_admin_config = config
    end

    def unload_resources!
      resources.each do |resource|
        parent = (module_name || 'Object').constantize
        name   = resource.controller_name.split('::').last
        #nodyna <send-17> <SD MODERATE (private methods)>
        parent.send(:remove_const, name) if parent.const_defined? name

        resource.controller.active_admin_config = nil
        if resource.is_a?(Resource) && resource.dsl
          resource.dsl.run_registration_block { @config = nil }
        end
      end
      @resources = ResourceCollection.new
    end

    def register_module
      unless Object.const_defined? module_name
        #nodyna <const_set-18> <CS COMPLEX (change-prone variable)>
        Object.const_set module_name, Module.new
      end
    end

    def register_resource_controller(config)
      #nodyna <eval-19> <EV COMPLEX (class definition)>
      eval "class ::#{config.controller_name} < ActiveAdmin::ResourceController; end"
      config.controller.active_admin_config = config
    end

    def parse_registration_block(config, resource_class, &block)
      config.dsl = ResourceDSL.new(config, resource_class)
      config.dsl.run_registration_block(&block)
    end

    def parse_page_registration_block(config, &block)
      PageDSL.new(config).run_registration_block(&block)
    end

    class Store
      include Enumerable
      delegate :[], :[]=, :empty?, to: :@namespaces

      def initialize
        @namespaces = {}
      end

      def each(&block)
        @namespaces.values.each(&block)
      end

      def names
        @namespaces.keys
      end
    end
  end
end
