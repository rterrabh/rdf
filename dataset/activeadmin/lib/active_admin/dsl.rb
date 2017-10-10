module ActiveAdmin

  class DSL

    def initialize(config)
      @config = config
    end

    def run_registration_block(&block)
      #nodyna <instance_exec-68> <IEX COMPLEX (block without parameters)>
      instance_exec &block if block_given?
    end

    def config
      @config
    end

    def include(mod)
      mod.included(self)
    end

    def controller(&block)
      @config.controller.class_exec(&block) if block_given?
      @config.controller
    end

    def action_item(name = nil, options = {}, &block)
      if name.is_a?(Hash)
        options = name
        name = nil
      end

      Deprecation.warn "using `action_item` without a name is deprecated! Use `action_item(:edit)`." unless name

      config.add_action_item(name, options, &block)
    end

    def batch_action(title, options = {}, &block)
      if title.is_a? String
        sym = title.titleize.tr(' ', '').underscore.to_sym
      else
        sym = title
        title = sym.to_s.titleize
      end

      unless options == false
        config.add_batch_action( sym, title, options, &block )
      else
        config.remove_batch_action sym
      end
    end

    def menu(options = {})
      config.menu_item_options = options
    end

    def navigation_menu(menu_name=nil, &block)
      config.navigation_menu_name = menu_name || block
    end

    def breadcrumb(&block)
      config.breadcrumb = block
    end

    def sidebar(name, options = {}, &block)
      config.sidebar_sections << ActiveAdmin::SidebarSection.new(name, options, &block)
    end

    def decorate_with(decorator_class)
      config.decorator_class_name = "::#{ decorator_class }"
    end
  end
end
