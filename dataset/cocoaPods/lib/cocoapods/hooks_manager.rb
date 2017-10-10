require 'rubygems'

module Pod
  module HooksManager
    class Hook
      attr_reader :plugin_name

      attr_reader :name

      attr_reader :block

      def initialize(name, plugin_name, block)
        raise ArgumentError, 'Missing name' unless name
        raise ArgumentError, 'Missing block' unless block

        UI.warn '[Hooks] The use of hooks without specifying a `plugin_name` ' \
                #nodyna <eval-2710> <not yet classified>
                "has been deprecated (from file `#{block.binding.eval('File.expand_path __FILE__')}`)." unless plugin_name

        @name = name
        @plugin_name = plugin_name
        @block = block
      end
    end

    class << self
      attr_reader :registrations

      def register(plugin_name, hook_name = nil, &block)
        if hook_name.nil?
          hook_name = plugin_name
          plugin_name = nil
        end

        @registrations ||= {}
        @registrations[hook_name] ||= []
        @registrations[hook_name] << Hook.new(hook_name, plugin_name, block)
      end

      def run(name, context, whitelisted_plugins = nil)
        raise ArgumentError, 'Missing name' unless name
        raise ArgumentError, 'Missing options' unless context

        if registrations
          hooks = registrations[name]
          if hooks
            UI.message "- Running #{name.to_s.gsub('_', ' ')} hooks" do
              hooks.each do |hook|
                next if whitelisted_plugins && !whitelisted_plugins.key?(hook.plugin_name)
                UI.message "- #{hook.plugin_name || 'unknown plugin'} from " \
                           "`#{hook.block.source_location.first}`" do
                  block = hook.block
                  if block.arity > 1
                    block.call(context, whitelisted_plugins[hook.plugin_name])
                  else
                    block.call(context)
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
