module HashiCorp
  module Rack
    class LegacyRedirect
      LEGACY_PATHS = {
        /^\/(v1|v2)/ => lambda { |env, _| "http://docs.vagrantup.com#{env["PATH_INFO"]}" }
      }

      def initialize(app)
        @app = app
      end

      def call(env)
        LEGACY_PATHS.each do |matcher, pather|
          data = matcher.match(env["PATH_INFO"])

          if data
            url = pather.call(env, data)
            headers = { "Content-Type" => "text/html", "location" => url }
            message = "Redirecting to new URL..."

            return [301, headers, [message]]
          end
        end

        @app.call(env)
      end
    end
  end
end
