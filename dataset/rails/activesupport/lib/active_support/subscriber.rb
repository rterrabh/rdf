require 'active_support/per_thread_registry'

module ActiveSupport
  class Subscriber
    class << self

      def attach_to(namespace, subscriber=new, notifier=ActiveSupport::Notifications)
        @namespace  = namespace
        @subscriber = subscriber
        @notifier   = notifier

        subscribers << subscriber

        subscriber.public_methods(false).each do |event|
          add_event_subscriber(event)
        end
      end

      def method_added(event)
        if public_method_defined?(event) && notifier
          add_event_subscriber(event)
        end
      end

      def subscribers
        @@subscribers ||= []
      end

      protected

      attr_reader :subscriber, :notifier, :namespace

      def add_event_subscriber(event)
        return if %w{ start finish }.include?(event.to_s)

        pattern = "#{event}.#{namespace}"

        return if subscriber.patterns.include?(pattern)

        subscriber.patterns << pattern
        notifier.subscribe(pattern, subscriber)
      end
    end

    attr_reader :patterns # :nodoc:

    def initialize
      @queue_key = [self.class.name, object_id].join "-"
      @patterns  = []
      super
    end

    def start(name, id, payload)
      e = ActiveSupport::Notifications::Event.new(name, Time.now, nil, id, payload)
      parent = event_stack.last
      parent << e if parent

      event_stack.push e
    end

    def finish(name, id, payload)
      finished  = Time.now
      event     = event_stack.pop
      event.end = finished
      event.payload.merge!(payload)

      method = name.split('.').first
      #nodyna <send-983> <SD COMPLEX (change-prone variables)>
      send(method, event)
    end

    private

      def event_stack
        SubscriberQueueRegistry.instance.get_queue(@queue_key)
      end
  end

  class SubscriberQueueRegistry # :nodoc:
    extend PerThreadRegistry

    def initialize
      @registry = {}
    end

    def get_queue(queue_key)
      @registry[queue_key] ||= []
    end
  end
end
