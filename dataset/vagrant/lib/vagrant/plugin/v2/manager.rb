require "log4r"

module Vagrant
  module Plugin
    module V2
      class Manager
        attr_reader :registered

        def initialize
          @logger = Log4r::Logger.new("vagrant::plugin::v2::manager")
          @registered = []
        end

        def action_hooks(hook_name)
          result = []

          @registered.each do |plugin|
            result += plugin.components.action_hooks[Plugin::ALL_ACTIONS]
            result += plugin.components.action_hooks[hook_name]
          end

          result
        end

        def commands
          Registry.new.tap do |result|
            @registered.each do |plugin|
              result.merge!(plugin.components.commands)
            end
          end
        end

        def communicators
          Registry.new.tap do |result|
            @registered.each do |plugin|
              result.merge!(plugin.communicator)
            end
          end
        end

        def config
          Registry.new.tap do |result|
            @registered.each do |plugin|
              result.merge!(plugin.components.configs[:top])
            end
          end
        end

        def guests
          Registry.new.tap do |result|
            @registered.each do |plugin|
              result.merge!(plugin.components.guests)
            end
          end
        end

        def guest_capabilities
          results = Hash.new { |h, k| h[k] = Registry.new }

          @registered.each do |plugin|
            plugin.components.guest_capabilities.each do |guest, caps|
              results[guest].merge!(caps)
            end
          end

          results
        end

        def hosts
          Registry.new.tap do |result|
            @registered.each do |plugin|
              result.merge!(plugin.components.hosts)
            end
          end
        end

        def host_capabilities
          results = Hash.new { |h, k| h[k] = Registry.new }

          @registered.each do |plugin|
            plugin.components.host_capabilities.each do |host, caps|
              results[host].merge!(caps)
            end
          end

          results
        end

        def providers
          Registry.new.tap do |result|
            @registered.each do |plugin|
              result.merge!(plugin.components.providers)
            end
          end
        end

        def provider_capabilities
          results = Hash.new { |h, k| h[k] = Registry.new }

          @registered.each do |plugin|
            plugin.components.provider_capabilities.each do |provider, caps|
              results[provider].merge!(caps)
            end
          end

          results
        end

        def provider_configs
          Registry.new.tap do |result|
            @registered.each do |plugin|
              result.merge!(plugin.components.configs[:provider])
            end
          end
        end

        def provisioner_configs
          Registry.new.tap do |result|
            @registered.each do |plugin|
              result.merge!(plugin.components.configs[:provisioner])
            end
          end
        end

        def provisioners
          Registry.new.tap do |result|
            @registered.each do |plugin|
              result.merge!(plugin.provisioner)
            end
          end
        end

        def pushes
          Registry.new.tap do |result|
            @registered.each do |plugin|
              result.merge!(plugin.components.pushes)
            end
          end
        end

        def push_configs
          Registry.new.tap do |result|
            @registered.each do |plugin|
              result.merge!(plugin.components.configs[:push])
            end
          end
        end

        def synced_folders
          Registry.new.tap do |result|
            @registered.each do |plugin|
              result.merge!(plugin.components.synced_folders)
            end
          end
        end

        def register(plugin)
          if !@registered.include?(plugin)
            @logger.info("Registered plugin: #{plugin.name}")
            @registered << plugin
          end
        end

        def reset!
          @registered.clear
        end

        def unregister(plugin)
          if @registered.include?(plugin)
            @logger.info("Unregistered: #{plugin.name}")
            @registered.delete(plugin)
          end
        end
      end
    end
  end
end
