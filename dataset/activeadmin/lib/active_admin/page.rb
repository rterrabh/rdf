module ActiveAdmin
  class Page

    attr_reader :namespace

    attr_reader :name

    attr_reader :page_actions

    attr_accessor :breadcrumb

    module Base
      def initialize(namespace, name, options)
        @namespace = namespace
        @name = name
        @options = options
        @page_actions = []
      end
    end

    include Base
    include Resource::Controllers
    include Resource::PagePresenters
    include Resource::Sidebars
    include Resource::ActionItems
    include Resource::Menu
    include Resource::Naming
    include Resource::Routes

    def plural_resource_label
      name
    end

    def resource_name
      @resource_name ||= Resource::Name.new(nil, name)
    end

    def underscored_resource_name
      resource_name.to_s.parameterize.underscore
    end

    def camelized_resource_name
      underscored_resource_name.camelize
    end

    def namespace_name
      namespace.name.to_s
    end

    def default_menu_options
      super.merge(id: resource_name)
    end

    def controller_name
      [namespace.module_name, camelized_resource_name + "Controller"].compact.join('::')
    end

    def route_uncountable?
      false
    end

    def belongs_to?
      false
    end

    def add_default_action_items
    end

    def add_default_sidebar_sections
    end

    def clear_page_actions!
      @page_actions = []
    end

  end
end
