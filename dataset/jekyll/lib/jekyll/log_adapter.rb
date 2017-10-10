module Jekyll
  class LogAdapter
    attr_reader :writer, :messages

    LOG_LEVELS = {
      :debug => ::Logger::DEBUG,
      :info  => ::Logger::INFO,
      :warn  => ::Logger::WARN,
      :error => ::Logger::ERROR
    }

    def initialize(writer, level = :info)
      @messages = []
      @writer = writer
      self.log_level = level
    end

    def log_level=(level)
      writer.level = LOG_LEVELS.fetch(level)
    end

    def adjust_verbosity(options = {})
      if options[:quiet]
        self.log_level = :error
      elsif options[:verbose]
        self.log_level = :debug
      end
      debug "Logging at level:", LOG_LEVELS.key(writer.level).to_s
    end

    def debug(topic, message = nil)
      writer.debug(message(topic, message))
    end

    def info(topic, message = nil)
      writer.info(message(topic, message))
    end

    def warn(topic, message = nil)
      writer.warn(message(topic, message))
    end

    def error(topic, message = nil)
      writer.error(message(topic, message))
    end

    def abort_with(topic, message = nil)
      error(topic, message)
      abort
    end

    def message(topic, message)
      msg = formatted_topic(topic) + message.to_s.gsub(/\s+/, ' ')
      messages << msg
      msg
    end

    def formatted_topic(topic)
      "#{topic} ".rjust(20)
    end
  end
end
