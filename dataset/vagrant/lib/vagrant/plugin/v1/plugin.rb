require "set"

require "log4r"

module Vagrant
  module Plugin
    module V1
      class Plugin
        ALL_ACTIONS = :__all_actions__

        LOGGER = Log4r::Logger.new("vagrant::plugin::v1::plugin")

        ROOT_CLASS = self

        def self.manager
          @manager ||= Manager.new
        end

        def self.name(name=UNSET_VALUE)
          result = get_or_set(:name, name)

          Plugin.manager.register(self) if name != UNSET_VALUE

          result
        end

        def self.description(value=UNSET_VALUE)
          get_or_set(:description, value)
        end

        def self.action_hook(name, &block)
          data[:action_hooks] ||= {}
          hooks = data[:action_hooks][name.to_sym] ||= []

          return hooks if !block_given?

          hooks << block
        end

        def self.command(name=UNSET_VALUE, &block)
          data[:command] ||= Registry.new

          if name != UNSET_VALUE
            if name.to_s !~ /^[-a-z0-9]+$/i
              raise InvalidCommandName, "Commands can only contain letters, numbers, and hyphens"
            end

            data[:command].register(name.to_sym, &block)
          end

          data[:command]
        end

        def self.communicator(name=UNSET_VALUE, &block)
          data[:communicator] ||= Registry.new

          data[:communicator].register(name.to_sym, &block) if name != UNSET_VALUE

          data[:communicator]
        end

        def self.config(name=UNSET_VALUE, upgrade_safe=false, &block)
          data[:config] ||= Registry.new

          if name != UNSET_VALUE
            data[:config].register(name.to_sym, &block)

            if upgrade_safe
              data[:config_upgrade_safe] ||= Set.new
              data[:config_upgrade_safe].add(name.to_sym)
            end
          end

          data[:config]
        end

        def self.guest(name=UNSET_VALUE, &block)
          data[:guests] ||= Registry.new

          data[:guests].register(name.to_sym, &block) if name != UNSET_VALUE

          data[:guests]
        end

        def self.host(name=UNSET_VALUE, &block)
          data[:hosts] ||= Registry.new

          data[:hosts].register(name.to_sym, &block) if name != UNSET_VALUE

          data[:hosts]
        end

        def self.provider(name=UNSET_VALUE, &block)
          data[:providers] ||= Registry.new

          data[:providers].register(name.to_sym, &block) if name != UNSET_VALUE

          data[:providers]
        end

        def self.provisioner(name=UNSET_VALUE, &block)
          data[:provisioners] ||= Registry.new

          data[:provisioners].register(name.to_sym, &block) if name != UNSET_VALUE

          data[:provisioners]
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
