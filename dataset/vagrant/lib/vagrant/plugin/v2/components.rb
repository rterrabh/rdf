module Vagrant
  module Plugin
    module V2
      class Components
        attr_reader :action_hooks

        attr_reader :commands

        attr_reader :configs

        attr_reader :guests

        attr_reader :guest_capabilities

        attr_reader :hosts

        attr_reader :host_capabilities

        attr_reader :providers

        attr_reader :provider_capabilities

        attr_reader :pushes

        attr_reader :synced_folders

        def initialize
          @action_hooks = Hash.new { |h, k| h[k] = [] }

          @commands = Registry.new
          @configs = Hash.new { |h, k| h[k] = Registry.new }
          @guests  = Registry.new
          @guest_capabilities = Hash.new { |h, k| h[k] = Registry.new }
          @hosts   = Registry.new
          @host_capabilities = Hash.new { |h, k| h[k] = Registry.new }
          @providers = Registry.new
          @provider_capabilities = Hash.new { |h, k| h[k] = Registry.new }
          @pushes = Registry.new
          @synced_folders = Registry.new
        end
      end
    end
  end
end
