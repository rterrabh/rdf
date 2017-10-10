require "active_support/notifications"

module ActiveSupport
  class DeprecationException < StandardError
  end

  class Deprecation
    DEFAULT_BEHAVIORS = {
      raise: ->(message, callstack) {
        e = DeprecationException.new(message)
        e.set_backtrace(callstack)
        raise e
      },

      stderr: ->(message, callstack) {
        $stderr.puts(message)
        $stderr.puts callstack.join("\n  ") if debug
      },

      log: ->(message, callstack) {
        logger =
            if defined?(Rails.logger) && Rails.logger
              Rails.logger
            else
              require 'active_support/logger'
              ActiveSupport::Logger.new($stderr)
            end
        logger.warn message
        logger.debug callstack.join("\n  ") if debug
      },

      notify: ->(message, callstack) {
        ActiveSupport::Notifications.instrument("deprecation.rails",
                                                :message => message, :callstack => callstack)
      },

      silence: ->(message, callstack) {},
    }

    module Behavior
      attr_accessor :debug

      def behavior
        @behavior ||= [DEFAULT_BEHAVIORS[:stderr]]
      end

      def behavior=(behavior)
        @behavior = Array(behavior).map { |b| DEFAULT_BEHAVIORS[b] || b }
      end
    end
  end
end
