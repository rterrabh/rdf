module Resque
  module Failure
    class Base
      attr_accessor :exception

      attr_accessor :worker

      attr_accessor :queue

      attr_accessor :payload

      def initialize(exception, worker, queue, payload)
        @exception = exception
        @worker    = worker
        @queue     = queue
        @payload   = payload
      end

      def save
      end

      def self.count(queue = nil, class_name = nil)
        0
      end

      def self.queues
        []
      end

      def self.all(offset = 0, limit = 1, queue = nil)
        []
      end

      def self.each(*args)
      end

      def self.url
      end
      
      def self.clear(*args)
      end
      
      def self.requeue(index)
      end

      def self.remove(index)
      end

      def log(message)
        @worker.log(message)
      end
    end
  end
end
