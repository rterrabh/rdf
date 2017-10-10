require "set"

module Vagrant
  module Config
    module V1
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
          @keys.each do |_key, instance|
            instance.finalize!
          end
        end

        def __internal_state
          {
            "config_map"        => @config_map,
            "keys"              => @keys,
            "missing_key_calls" => @missing_key_calls
          }
        end
      end
    end
  end
end
