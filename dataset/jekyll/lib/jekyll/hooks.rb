module Jekyll
  module Hooks
    OWNER_MAP = {
      Jekyll::Site => :site,
      Jekyll::Page => :page,
      Jekyll::Post => :post,
      Jekyll::Document => :document,
    }.freeze

    DEFAULT_PRIORITY = 20

    PRIORITY_MAP = {
      low: 10,
      normal: 20,
      high: 30,
    }.freeze

    @registry = {
      :site => {
        after_reset: [],
        post_read: [],
        pre_render: [],
        post_write: [],
      },
      :page => {
        post_init: [],
        pre_render: [],
        post_render: [],
        post_write: [],
      },
      :post => {
        post_init: [],
        pre_render: [],
        post_render: [],
        post_write: [],
      },
      :document => {
        pre_render: [],
        post_render: [],
        post_write: [],
      },
    }

    @hook_priority = {}

    NotAvailable = Class.new(RuntimeError)
    Uncallable = Class.new(RuntimeError)

    def self.register(owners, event, priority: DEFAULT_PRIORITY, &block)
      Array(owners).each do |owner|
        register_one(owner, event, priority_value(priority), &block)
      end
    end

    def self.priority_value(priority)
      return priority if priority.is_a?(Fixnum)
      PRIORITY_MAP[priority] || DEFAULT_PRIORITY
    end

    def self.register_one(owner, event, priority, &block)
      unless @registry[owner]
        raise NotAvailable, "Hooks are only available for the following " <<
          "classes: #{@registry.keys.inspect}"
      end

      unless @registry[owner][event]
        raise NotAvailable, "Invalid hook. #{owner} supports only the " <<
          "following hooks #{@registry[owner].keys.inspect}"
      end

      unless block.respond_to? :call
        raise Uncallable, "Hooks must respond to :call"
      end

      insert_hook owner, event, priority, &block
    end

    def self.insert_hook(owner, event, priority, &block)
      @hook_priority[block] = "#{priority}.#{@hook_priority.size}".to_f
      @registry[owner][event] << block
    end

    def self.trigger(instance, event, *args)
      owner_symbol = OWNER_MAP[instance.class]

      return unless @registry[owner_symbol]
      return unless @registry[owner_symbol][event]

      hooks = @registry[owner_symbol][event]

      hooks.sort_by { |h| @hook_priority[h] }.each do |hook|
        hook.call(instance, *args)
      end
    end
  end
end
