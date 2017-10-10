module ActionController
  module Caching
    module Fragments
      def fragment_cache_key(key)
        ActiveSupport::Cache.expand_cache_key(key.is_a?(Hash) ? url_for(key).split("://").last : key, :views)
      end

      def write_fragment(key, content, options = nil)
        return content unless cache_configured?

        key = fragment_cache_key(key)
        instrument_fragment_cache :write_fragment, key do
          content = content.to_str
          cache_store.write(key, content, options)
        end
        content
      end

      def read_fragment(key, options = nil)
        return unless cache_configured?

        key = fragment_cache_key(key)
        instrument_fragment_cache :read_fragment, key do
          result = cache_store.read(key, options)
          result.respond_to?(:html_safe) ? result.html_safe : result
        end
      end

      def fragment_exist?(key, options = nil)
        return unless cache_configured?
        key = fragment_cache_key(key)

        instrument_fragment_cache :exist_fragment?, key do
          cache_store.exist?(key, options)
        end
      end

      def expire_fragment(key, options = nil)
        return unless cache_configured?
        key = fragment_cache_key(key) unless key.is_a?(Regexp)

        instrument_fragment_cache :expire_fragment, key do
          if key.is_a?(Regexp)
            cache_store.delete_matched(key, options)
          else
            cache_store.delete(key, options)
          end
        end
      end

      def instrument_fragment_cache(name, key) # :nodoc:
        payload = {
          controller: controller_name,
          action: action_name,
          key: key
        }

        ActiveSupport::Notifications.instrument("#{name}.action_controller", payload) { yield }
      end
    end
  end
end
