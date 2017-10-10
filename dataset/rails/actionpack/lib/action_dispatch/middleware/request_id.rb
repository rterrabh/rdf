require 'securerandom'
require 'active_support/core_ext/string/access'

module ActionDispatch
  class RequestId
    def initialize(app)
      @app = app
    end

    def call(env)
      env["action_dispatch.request_id"] = external_request_id(env) || internal_request_id
      @app.call(env).tap { |_status, headers, _body| headers["X-Request-Id"] = env["action_dispatch.request_id"] }
    end

    private
      def external_request_id(env)
        if request_id = env["HTTP_X_REQUEST_ID"].presence
          request_id.gsub(/[^\w\-]/, "").first(255)
        end
      end

      def internal_request_id
        SecureRandom.uuid
      end
  end
end
