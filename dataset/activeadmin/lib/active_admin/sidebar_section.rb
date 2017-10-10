module ActiveAdmin

  class SidebarSection
    include ActiveAdmin::OptionalDisplay

    attr_accessor :name, :options, :block

    def initialize(name, options = {}, &block)
      @name, @options, @block = name, options, block
      normalize_display_options!
    end

    def id
      "#{name.to_s.downcase.underscore}_sidebar_section".parameterize
    end

    def icon?
      !!options[:icon]
    end

    def icon
      options[:icon] if icon?
    end

    def title
      I18n.t("active_admin.sidebars.#{name.to_s}", default: name.to_s.titlecase)
    end

    def partial_name
      options[:partial] || "#{name.to_s.downcase.tr(' ', '_')}_sidebar"
    end

    def custom_class
      options[:class]
    end

    def priority
      options[:priority] || 10
    end
  end

end
