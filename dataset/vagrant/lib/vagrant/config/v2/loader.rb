require "vagrant/config/v2/root"

module Vagrant
  module Config
    module V2
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

          old_state["config_map"].each do |k, _|
            #nodyna <send-3077> <SD COMPLEX (change-prone variables)>
            old.public_send(k)
          end
          new_state["config_map"].each do |k, _|
            #nodyna <send-3078> <SD COMPLEX (change-prone variables)>
            new.public_send(k)
          end

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

          new_missing_key_calls =
            old_state["missing_key_calls"] + new_state["missing_key_calls"]

          V2::Root.new(config_map).tap do |result|
            result.__set_internal_state({
              "config_map"        => config_map,
              "keys"              => keys,
              "missing_key_calls" => new_missing_key_calls
            })
          end
        end

        def self.upgrade(old)
          root = new_root_object

          warnings = []
          errors   = []

          old.__internal_state["keys"].each do |_, old_value|
            if old_value.respond_to?(:upgrade)
              result = old_value.upgrade(root)

              if result.is_a?(Array)
                warnings += result[0]
                errors   += result[1]
              end
            end
          end

          old.__internal_state["missing_key_calls"].to_a.sort.each do |key|
            warnings << I18n.t("vagrant.config.loader.bad_v1_key", key: key)
          end

          [root, warnings, errors]
        end

        protected

        def self.new_root_object
          config_map = Vagrant.plugin("2").manager.config

          V2::Root.new(config_map)
        end
      end
    end
  end
end
