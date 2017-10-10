require "set"

require "log4r"

require "vagrant/plugin/v2/components"

module Vagrant
  module Plugin
    module V2
      class Plugin
        ALL_ACTIONS = :__all_actions__

        LOGGER = Log4r::Logger.new("vagrant::plugin::v2::plugin")

        ROOT_CLASS = self

        def self.manager
          @manager ||= Manager.new
        end

        def self.components
          @components ||= Components.new
        end

        def self.name(name=UNSET_VALUE)
          result = get_or_set(:name, name)

          Plugin.manager.register(self) if name != UNSET_VALUE

          result
        end

        def self.description(value=UNSET_VALUE)
          get_or_set(:description, value)
        end

        def self.action_hook(name, hook_name=nil, &block)

          hook_name ||= ALL_ACTIONS
          components.action_hooks[hook_name.to_sym] << block
        end

        def self.command(name, **opts, &block)
          if name.to_s !~ /^[-a-z0-9]+$/i
            raise InvalidCommandName, "Commands can only contain letters, numbers, and hyphens"
          end

          opts[:primary] = true if !opts.key?(:primary)

          components.commands.register(name.to_sym) do
            [block, opts]
          end

          nil
        end

        def self.communicator(name=UNSET_VALUE, &block)
          data[:communicator] ||= Registry.new

          data[:communicator].register(name.to_sym, &block) if name != UNSET_VALUE

          data[:communicator]
        end

        def self.config(name, scope=nil, &block)
          scope ||= :top
          components.configs[scope].register(name.to_sym, &block)
          nil
        end

        def self.guest(name, parent=nil, &block)
          components.guests.register(name.to_sym) do
            parent = parent.to_sym if parent

            [block.call, parent]
          end
          nil
        end

        def self.guest_capability(guest, cap, &block)
          components.guest_capabilities[guest.to_sym].register(cap.to_sym, &block)
          nil
        end

        def self.host(name, parent=nil, &block)
          components.hosts.register(name.to_sym) do
            parent = parent.to_sym if parent

            [block.call, parent]
          end
          nil
        end

        def self.host_capability(host, cap, &block)
          components.host_capabilities[host.to_sym].register(cap.to_sym, &block)
          nil
        end

        def self.provider(name=UNSET_VALUE, options=nil, &block)
          options ||= {}
          options[:priority] ||= 5

          components.providers.register(name.to_sym) do
            [block.call, options]
          end

          nil
        end

        def self.provider_capability(provider, cap, &block)
          components.provider_capabilities[provider.to_sym].register(cap.to_sym, &block)
          nil
        end

        def self.provisioner(name=UNSET_VALUE, &block)
          data[:provisioners] ||= Registry.new

          data[:provisioners].register(name.to_sym, &block) if name != UNSET_VALUE

          data[:provisioners]
        end

        def self.push(name, options=nil, &block)
          components.pushes.register(name.to_sym) do
            [block.call, options]
          end

          nil
        end

        def self.synced_folder(name, priority=10, &block)
          components.synced_folders.register(name.to_sym) do
            [block.call, priority]
          end

          nil
        end

        def self.data
          @data ||= {}
        end

        protected

        UNSET_VALUE = Object.new

        def self.get_or_set(key, value=UNSET_VALUE)
          return data[key] if value.eql?(UNSET_VALUE)

          data[key] = value
        end
      end
    end
  end
end
