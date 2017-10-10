require "vagrant/config/v1/root"

module Vagrant
  module Config
    module V1
      class Loader < VersionBase
        def self.init
          new_root_object
        end

        def self.finalize(config)
          config.finalize!

          config
        end

        def self.load(config_proc)
          root = new_root_object

          config_proc.call(root)

          root
        end

        def self.merge(old, new)
          old_state = old.__internal_state
          new_state = new.__internal_state

          config_map = old_state["config_map"].merge(new_state["config_map"])

          old_keys = old_state["keys"]
          new_keys = new_state["keys"]
          keys     = {}
          old_keys.each do |key, old_value|
            if new_keys.key?(key)
              keys[key] = old_value.merge(new_keys[key])
            else
              keys[key] = old_value.dup
            end
          end

          new_keys.each do |key, new_value|
            if !keys.key?(key)
              keys[key] = new_value.dup
            end
          end

          V1::Root.new(config_map, keys)
        end

        protected

        def self.new_root_object
          config_map = nil
          plugin_manager = Vagrant.plugin("1").manager
          if Config::CURRENT_VERSION == "1"
            config_map = plugin_manager.config
          else
            config_map = plugin_manager.config_upgrade_safe
          end

          V1::Root.new(config_map)
        end
      end
    end
  end
end
