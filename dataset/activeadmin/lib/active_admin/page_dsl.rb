module ActiveAdmin
  class PageDSL < DSL

    def content(options = {}, &block)
      config.set_page_presenter :index, ActiveAdmin::PagePresenter.new(options, &block)
    end

    def page_action(name, options = {}, &block)
      config.page_actions << ControllerAction.new(name, options)
      controller do
        #nodyna <define_method-34> <DM COMPLEX (events)>
        define_method(name, &block || Proc.new{})
      end
    end
  end
end
