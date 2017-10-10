module Spree
  module TestingSupport
    module ControllerRequests
      extend ActiveSupport::Concern

      included do
        routes { Spree::Core::Engine.routes }
      end

      def spree_get(action, parameters = nil, session = nil, flash = nil)
        process_spree_action(action, parameters, session, flash, "GET")
      end

      def spree_post(action, parameters = nil, session = nil, flash = nil)
        process_spree_action(action, parameters, session, flash, "POST")
      end

      def spree_put(action, parameters = nil, session = nil, flash = nil)
        process_spree_action(action, parameters, session, flash, "PUT")
      end

      def spree_delete(action, parameters = nil, session = nil, flash = nil)
        process_spree_action(action, parameters, session, flash, "DELETE")
      end

      def spree_xhr_get(action, parameters = nil, session = nil, flash = nil)
        process_spree_xhr_action(action, parameters, session, flash, :get)
      end

      def spree_xhr_post(action, parameters = nil, session = nil, flash = nil)
        process_spree_xhr_action(action, parameters, session, flash, :post)
      end

      def spree_xhr_put(action, parameters = nil, session = nil, flash = nil)
        process_spree_xhr_action(action, parameters, session, flash, :put)
      end

      def spree_xhr_delete(action, parameters = nil, session = nil, flash = nil)
        process_spree_xhr_action(action, parameters, session, flash, :delete)
      end

      private

      def process_spree_action(action, parameters = nil, session = nil, flash = nil, method = "GET")
        parameters ||= {}
        process(action, method, parameters, session, flash)
      end

      def process_spree_xhr_action(action, parameters = nil, session = nil, flash = nil, method = :get)
        parameters ||= {}
        parameters.reverse_merge!(:format => :json)
        xml_http_request(method, action, parameters, session, flash)
      end
    end
  end
end
