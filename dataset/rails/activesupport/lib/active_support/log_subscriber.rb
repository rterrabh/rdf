require 'active_support/core_ext/module/attribute_accessors'
require 'active_support/core_ext/class/attribute'
require 'active_support/subscriber'

module ActiveSupport
  class LogSubscriber < Subscriber
    CLEAR   = "\e[0m"
    BOLD    = "\e[1m"

    BLACK   = "\e[30m"
    RED     = "\e[31m"
    GREEN   = "\e[32m"
    YELLOW  = "\e[33m"
    BLUE    = "\e[34m"
    MAGENTA = "\e[35m"
    CYAN    = "\e[36m"
    WHITE   = "\e[37m"

    mattr_accessor :colorize_logging
    self.colorize_logging = true

    class << self
      def logger
        @logger ||= if defined?(Rails) && Rails.respond_to?(:logger)
          Rails.logger
        end
      end

      attr_writer :logger

      def log_subscribers
        subscribers
      end

      def flush_all!
        logger.flush if logger.respond_to?(:flush)
      end
    end

    def logger
      LogSubscriber.logger
    end

    def start(name, id, payload)
      super if logger
    end

    def finish(name, id, payload)
      super if logger
    rescue Exception => e
      logger.error "Could not log #{name.inspect} event. #{e.class}: #{e.message} #{e.backtrace}"
    end

  protected

    %w(info debug warn error fatal unknown).each do |level|
      #nodyna <class_eval-1034> <CE MODERATE (define methods)>
      class_eval <<-METHOD, __FILE__, __LINE__ + 1
        def #{level}(progname = nil, &block)
          logger.#{level}(progname, &block) if logger
        end
      METHOD
    end

    def color(text, color, bold=false)
      return text unless colorize_logging
      #nodyna <const_get-1035> <CG MODERATE (change-prone variable)>
      color = self.class.const_get(color.upcase) if color.is_a?(Symbol)
      bold  = bold ? BOLD : ""
      "#{bold}#{color}#{text}#{CLEAR}"
    end
  end
end
