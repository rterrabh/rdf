require 'active_support/core_ext/module/attribute_accessors'
require 'active_support/logger_silence'
require 'logger'

module ActiveSupport
  class Logger < ::Logger
    include LoggerSilence

    # Broadcasts logs to multiple loggers.
    def self.broadcast(logger) # :nodoc:
      Module.new do
        #nodyna <ID:define_method-42> <DM MODERATE (events)>
        define_method(:add) do |*args, &block|
          logger.add(*args, &block)
          super(*args, &block)
        end

        #nodyna <ID:define_method-43> <DM MODERATE (events)>
        define_method(:<<) do |x|
          logger << x
          super(x)
        end

        #nodyna <ID:define_method-44> <DM MODERATE (events)>
        define_method(:close) do
          logger.close
          super()
        end

        #nodyna <ID:define_method-45> <DM MODERATE (events)>
        define_method(:progname=) do |name|
          logger.progname = name
          super(name)
        end

        #nodyna <ID:define_method-46> <DM MODERATE (events)>
        define_method(:formatter=) do |formatter|
          logger.formatter = formatter
          super(formatter)
        end

        #nodyna <ID:define_method-47> <DM MODERATE (events)>
        define_method(:level=) do |level|
          logger.level = level
          super(level)
        end
      end
    end

    def initialize(*args)
      super
      @formatter = SimpleFormatter.new
    end

    # Simple formatter which only displays the message.
    class SimpleFormatter < ::Logger::Formatter
      # This method is invoked when a log event occurs
      def call(severity, timestamp, progname, msg)
        "#{String === msg ? msg : msg.inspect}\n"
      end
    end
  end
end
