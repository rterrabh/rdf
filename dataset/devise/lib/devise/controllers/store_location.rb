require "uri"

module Devise
  module Controllers
    module StoreLocation
      def stored_location_for(resource_or_scope)
        session_key = stored_location_key_for(resource_or_scope)

        if is_navigational_format?
          session.delete(session_key)
        else
          session[session_key]
        end
      end

      def store_location_for(resource_or_scope, location)
        session_key = stored_location_key_for(resource_or_scope)
        uri = parse_uri(location)
        if uri
          session[session_key] = [uri.path.sub(/\A\/+/, '/'), uri.query].compact.join('?')
        end
      end

      private

      def parse_uri(location)
        location && URI.parse(location)
      rescue URI::InvalidURIError
        nil
      end

      def stored_location_key_for(resource_or_scope)
        scope = Devise::Mapping.find_scope!(resource_or_scope)
        "#{scope}_return_to"
      end
    end
  end
end
