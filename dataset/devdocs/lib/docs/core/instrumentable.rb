require 'active_support/notifications'

module Docs
  module Instrumentable
    def self.extended(base)
      #nodyna <send-2736> <SD TRIVIAL (public methods)>
      base.send :extend, Methods
    end

    def self.included(base)
      #nodyna <send-2737> <SD TRIVIAL (public methods)>
      base.send :include, Methods
    end

    module Methods
      def instrument(*args, &block)
        ActiveSupport::Notifications.instrument(*args, &block)
      end

      def subscribe(*args, &block)
        ActiveSupport::Notifications.subscribe(*args, &block)
      end
    end
  end
end
