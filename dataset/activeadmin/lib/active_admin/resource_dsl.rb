module ActiveAdmin
  class ResourceDSL < DSL
    def initialize(config, resource_class)
      @resource = resource_class
      super(config)
    end

    private

    def belongs_to(target, options = {})
      config.belongs_to(target, options)
    end

    def scope_to(*args, &block)
      config.scope_to(*args, &block)
    end

    def scope(*args, &block)
      config.scope(*args, &block)
    end

    def includes(*args)
      config.includes.push *args
    end

    def permit_params(*args, &block)
      param_key = config.param_key.to_sym

      controller do
        #nodyna <define_method-10> <DM COMPLEX (events)>
        define_method :permitted_params do
          params.permit *active_admin_namespace.permitted_params,
            #nodyna <instance_exec-11> <IEX COMPLEX (block without parameters)>
            param_key => block ? instance_exec(&block) : args
        end
      end
    end

    def index(options = {}, &block)
      options[:as] ||= :table
      config.set_page_presenter :index, ActiveAdmin::PagePresenter.new(options, &block)
    end

    def show(options = {}, &block)
      config.set_page_presenter :show, ActiveAdmin::PagePresenter.new(options, &block)
    end

    def form(options = {}, &block)
      config.set_page_presenter :form, ActiveAdmin::PagePresenter.new(options, &block)
    end

    def csv(options={}, &block)
      options[:resource] = @resource

      config.csv_builder = CSVBuilder.new(options, &block)
    end

    def action(set, name, options = {}, &block)
      set << ControllerAction.new(name, options)
      title = options.delete(:title)

      controller do
        before_filter(only: [name]) { @page_title = title } if title
        #nodyna <define_method-12> <DM COMPLEX (events)>
        define_method(name, &block || Proc.new{})
      end
    end

    def member_action(name, options = {}, &block)
      action config.member_actions, name, options, &block
    end

    def collection_action(name, options = {}, &block)
      action config.collection_actions, name, options, &block
    end

    delegate :before_build,   :after_build,   to: :controller
    delegate :before_create,  :after_create,  to: :controller
    delegate :before_update,  :after_update,  to: :controller
    delegate :before_save,    :after_save,    to: :controller
    delegate :before_destroy, :after_destroy, to: :controller

    delegate :before_filter, :skip_before_filter, :after_filter, :skip_after_filter, :around_filter, :skip_filter,
             to: :controller

    delegate :actions, to: :controller

  end
end
