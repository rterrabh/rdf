require "log4r"

module Vagrant
  module Plugin
    module V1
      class Manager
        attr_reader :registered

        def initialize
          @logger = Log4r::Logger.new("vagrant::plugin::v1::manager")
          @registered = []
        end

        def communicators
          result = {}

          @registered.each do |plugin|
            result.merge!(plugin.communicator.to_hash)
          end

          result
        end

        def config
          result = {}

          @registered.each do |plugin|
            plugin.config.each do |key, klass|
              result[key] = klass
            end
          end

          result
        end

        def config_upgrade_safe
          result = {}

          @registered.each do |plugin|
            configs = plugin.data[:config_upgrade_safe]
            if configs
              configs.each do |key|
                result[key] = plugin.config.get(key)
              end
            end
          end

          result
        end

        def guests
          result = {}

          @registered.each do |plugin|
            result.merge!(plugin.guest.to_hash)
          end

          result
        end

        def hosts
          hosts = {}

          @registered.each do |plugin|
            hosts.merge!(plugin.host.to_hash)
          end

          hosts
        end

        def providers
          providers = {}

          @registered.each do |plugin|
            providers.merge!(plugin.provider.to_hash)
          end

          providers
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
