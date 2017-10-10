require 'securerandom'

module ActiveSupport
  module Notifications
    class Instrumenter
      attr_reader :id

      def initialize(notifier)
        @id       = unique_id
        @notifier = notifier
      end

      def instrument(name, payload={})
        start name, payload
        begin
          yield payload
        rescue Exception => e
          payload[:exception] = [e.class.name, e.message]
          raise e
        ensure
          finish name, payload
        end
      end

      def start(name, payload)
        @notifier.start name, @id, payload
      end

      def finish(name, payload)
        @notifier.finish name, @id, payload
      end

      private

      def unique_id
        SecureRandom.hex(10)
      end
    end

    class Event
      attr_reader :name, :time, :transaction_id, :payload, :children
      attr_accessor :end

      def initialize(name, start, ending, transaction_id, payload)
        @name           = name
        @payload        = payload.dup
        @time           = start
        @transaction_id = transaction_id
        @end            = ending
        @children       = []
        @duration       = nil
      end

      def duration
        @duration ||= 1000.0 * (self.end - time)
      end

      def <<(event)
        @children << event
      end

      def parent_of?(event)
        @children.include? event
      end
    end
  end
end
