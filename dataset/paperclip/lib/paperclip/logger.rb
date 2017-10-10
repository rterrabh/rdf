module Paperclip
  module Logger
    def log message
      logger.info("[paperclip] #{message}") if logging?
    end

    def logger #:nodoc:
      @logger ||= options[:logger] || ::Logger.new(STDOUT)
    end

    def logger=(logger)
      @logger = logger
    end

    def logging? #:nodoc:
      options[:log]
    end
  end
end
