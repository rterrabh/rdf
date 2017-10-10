require "set"

require "vagrant/config/v2/util"

module Vagrant
  module Config
    module V2
      class Root
        def initialize(config_map, keys=nil)
          @keys              = keys || {}
          @config_map        = config_map
          @missing_key_calls = Set.new
        end

        def method_missing(name, *args)
          return @keys[name] if @keys.key?(name)

          config_klass = @config_map[name.to_sym]
          if config_klass
            @keys[name] = config_klass.new
            return @keys[name]
          else
            @missing_key_calls.add(name.to_s)
            return DummyConfig.new
          end
        end

        def finalize!
          @config_map.each do |key, klass|
            if !@keys.key?(key)
              @keys[key] = klass.new
            end
          end

          @keys.each do |_key, instance|
            instance.finalize!
            instance._finalize!
          end
        end

        def validate(machine)
          errors = {}
          @keys.each do |_key, instance|
            if instance.respond_to?(:validate)
              result = instance.validate(machine)
              if result && !result.empty?
                errors = Util.merge_errors(errors, result)
              end
            end
          end

          errors.keys.each do |key|
            errors.delete(key) if errors[key].empty?
          end

          if !@missing_key_calls.empty?
            errors["Vagrant"] = @missing_key_calls.to_a.sort.map do |key|
              I18n.t("vagrant.config.root.bad_key", key: key)
            end
          end

          errors
        end

        def __internal_state
          {
            "config_map"        => @config_map,
            "keys"              => @keys,
            "missing_key_calls" => @missing_key_calls
          }
        end

        def __set_internal_state(state)
          @config_map        = state["config_map"] if state.key?("config_map")
          @keys              = state["keys"] if state.key?("keys")
          @missing_key_calls = state["missing_key_calls"] if state.key?("missing_key_calls")
        end
      end
    end
  end
end
