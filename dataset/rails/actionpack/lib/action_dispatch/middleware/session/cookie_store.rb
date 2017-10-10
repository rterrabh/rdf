require 'active_support/core_ext/hash/keys'
require 'action_dispatch/middleware/session/abstract_store'
require 'rack/session/cookie'

module ActionDispatch
  module Session
    class CookieStore < Rack::Session::Abstract::ID
      include Compatibility
      include StaleSessionCheck
      include SessionObject

      def initialize(app, options={})
        super(app, options.merge!(:cookie_only => true))
      end

      def destroy_session(env, session_id, options)
        new_sid = generate_sid unless options[:drop]
        env["action_dispatch.request.unsigned_session_cookie"] = new_sid ? { "session_id" => new_sid } : {}
        new_sid
      end

      def load_session(env)
        stale_session_check! do
          data = unpacked_cookie_data(env)
          data = persistent_session_id!(data)
          [data["session_id"], data]
        end
      end

      private

      def extract_session_id(env)
        stale_session_check! do
          unpacked_cookie_data(env)["session_id"]
        end
      end

      def unpacked_cookie_data(env)
        env["action_dispatch.request.unsigned_session_cookie"] ||= begin
          stale_session_check! do
            if data = get_cookie(env)
              data.stringify_keys!
            end
            data || {}
          end
        end
      end

      def persistent_session_id!(data, sid=nil)
        data ||= {}
        data["session_id"] ||= sid || generate_sid
        data
      end

      def set_session(env, sid, session_data, options)
        session_data["session_id"] = sid
        session_data
      end

      def set_cookie(env, session_id, cookie)
        cookie_jar(env)[@key] = cookie
      end

      def get_cookie(env)
        cookie_jar(env)[@key]
      end

      def cookie_jar(env)
        request = ActionDispatch::Request.new(env)
        request.cookie_jar.signed_or_encrypted
      end
    end
  end
end
