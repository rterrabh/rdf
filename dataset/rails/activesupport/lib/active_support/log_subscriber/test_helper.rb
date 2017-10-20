require 'active_support/log_subscriber'
require 'active_support/logger'
require 'active_support/notifications'

module ActiveSupport
  class LogSubscriber
    module TestHelper
      def setup
        @logger   = MockLogger.new
        @notifier = ActiveSupport::Notifications::Fanout.new

        ActiveSupport::LogSubscriber.colorize_logging = false

        @old_notifier = ActiveSupport::Notifications.notifier
        set_logger(@logger)
        ActiveSupport::Notifications.notifier = @notifier
      end

      def teardown
        set_logger(nil)
        ActiveSupport::Notifications.notifier = @old_notifier
      end

      class MockLogger
        include ActiveSupport::Logger::Severity

        attr_reader :flush_count
        attr_accessor :level

        def initialize(level = DEBUG)
          @flush_count = 0
          @level = level
          @logged = Hash.new { |h,k| h[k] = [] }
        end

        def method_missing(level, message = nil)
           if block_given?
             @logged[level] << yield
           else
             @logged[level] << message
           end
        end

        def logged(level)
          @logged[level].compact.map { |l| l.to_s.strip }
        end

        def flush
          @flush_count += 1
        end

        ActiveSupport::Logger::Severity.constants.each do |severity|
          #nodyna <class_eval-1024> <CE MODERATE (define methods)>
          class_eval <<-EOT, __FILE__, __LINE__ + 1
            def #{severity.downcase}?
            end
          EOT
        end
      end

      def wait
        @notifier.wait
      end

      def set_logger(logger)
        ActiveSupport::LogSubscriber.logger = logger
      end
    end
  end
end
