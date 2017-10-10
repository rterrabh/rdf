require 'active_support/core_ext/module/attribute_accessors'
require 'active_support/logger_silence'
require 'logger'

module ActiveSupport
  class Logger < ::Logger
    include LoggerSilence

    def self.broadcast(logger) # :nodoc:
      Module.new do
        #nodyna <define_method-976> <DM MODERATE (events)>
        define_method(:add) do |*args, &block|
          logger.add(*args, &block)
          super(*args, &block)
        end

        #nodyna <define_method-977> <DM MODERATE (events)>
        define_method(:<<) do |x|
          logger << x
          super(x)
        end

        #nodyna <define_method-978> <DM MODERATE (events)>
        define_method(:close) do
          logger.close
          super()
        end

        #nodyna <define_method-979> <DM MODERATE (events)>
        define_method(:progname=) do |name|
          logger.progname = name
          super(name)
        end

        #nodyna <define_method-980> <DM MODERATE (events)>
        define_method(:formatter=) do |formatter|
          logger.formatter = formatter
          super(formatter)
        end

        #nodyna <define_method-981> <DM MODERATE (events)>
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

    class SimpleFormatter < ::Logger::Formatter
      def call(severity, timestamp, progname, msg)
        "#{String === msg ? msg : msg.inspect}\n"
      end
    end
  end
end
