require 'action_dispatch/middleware/session/abstract_store'

module ActionDispatch
  module Session
    class CacheStore < AbstractStore
      def initialize(app, options = {})
        @cache = options[:cache] || Rails.cache
        options[:expire_after] ||= @cache.options[:expires_in]
        super
      end

      def get_session(env, sid)
        unless sid and session = @cache.read(cache_key(sid))
          sid, session = generate_sid, {}
        end
        [sid, session]
      end

      def set_session(env, sid, session, options)
        key = cache_key(sid)
        if session
          @cache.write(key, session, :expires_in => options[:expire_after])
        else
          @cache.delete(key)
        end
        sid
      end

      def destroy_session(env, sid, options)
        @cache.delete(cache_key(sid))
        generate_sid
      end

      private
        def cache_key(sid)
          "_session_id:#{sid}"
        end
    end
  end
end
