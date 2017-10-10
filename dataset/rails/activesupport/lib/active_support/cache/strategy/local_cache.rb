require 'active_support/core_ext/object/duplicable'
require 'active_support/core_ext/string/inflections'
require 'active_support/per_thread_registry'

module ActiveSupport
  module Cache
    module Strategy
      module LocalCache
        autoload :Middleware, 'active_support/cache/strategy/local_cache_middleware'

        class LocalCacheRegistry # :nodoc:
          extend ActiveSupport::PerThreadRegistry

          def initialize
            @registry = {}
          end

          def cache_for(local_cache_key)
            @registry[local_cache_key]
          end

          def set_cache_for(local_cache_key, value)
            @registry[local_cache_key] = value
          end

          def self.set_cache_for(l, v); instance.set_cache_for l, v; end
          def self.cache_for(l); instance.cache_for l; end
        end

        class LocalStore < Store
          def initialize
            super
            @data = {}
          end

          def synchronize # :nodoc:
            yield
          end

          def clear(options = nil)
            @data.clear
          end

          def read_entry(key, options)
            @data[key]
          end

          def write_entry(key, value, options)
            @data[key] = value
            true
          end

          def delete_entry(key, options)
            !!@data.delete(key)
          end
        end

        def with_local_cache
          use_temporary_local_cache(LocalStore.new) { yield }
        end
        def middleware
          @middleware ||= Middleware.new(
            "ActiveSupport::Cache::Strategy::LocalCache",
            local_cache_key)
        end

        def clear(options = nil) # :nodoc:
          local_cache.clear(options) if local_cache
          super
        end

        def cleanup(options = nil) # :nodoc:
          local_cache.clear(options) if local_cache
          super
        end

        def increment(name, amount = 1, options = nil) # :nodoc:
          value = bypass_local_cache{super}
          set_cache_value(value, name, amount, options)
          value
        end

        def decrement(name, amount = 1, options = nil) # :nodoc:
          value = bypass_local_cache{super}
          set_cache_value(value, name, amount, options)
          value
        end

        protected
          def read_entry(key, options) # :nodoc:
            if local_cache
              entry = local_cache.read_entry(key, options)
              unless entry
                entry = super
                local_cache.write_entry(key, entry, options)
              end
              entry
            else
              super
            end
          end

          def write_entry(key, entry, options) # :nodoc:
            local_cache.write_entry(key, entry, options) if local_cache
            super
          end

          def delete_entry(key, options) # :nodoc:
            local_cache.delete_entry(key, options) if local_cache
            super
          end

          def set_cache_value(value, name, amount, options)
            if local_cache
              local_cache.mute do
                if value
                  local_cache.write(name, value, options)
                else
                  local_cache.delete(name, options)
                end
              end
            end
          end

        private

          def local_cache_key
            @local_cache_key ||= "#{self.class.name.underscore}_local_cache_#{object_id}".gsub(/[\/-]/, '_').to_sym
          end

          def local_cache
            LocalCacheRegistry.cache_for(local_cache_key)
          end

          def bypass_local_cache
            use_temporary_local_cache(nil) { yield }
          end

          def use_temporary_local_cache(temporary_cache)
            save_cache = LocalCacheRegistry.cache_for(local_cache_key)
            begin
              LocalCacheRegistry.set_cache_for(local_cache_key, temporary_cache)
              yield
            ensure
              LocalCacheRegistry.set_cache_for(local_cache_key, save_cache)
            end
          end
      end
    end
  end
end
