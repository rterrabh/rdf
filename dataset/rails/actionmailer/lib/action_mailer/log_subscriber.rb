require 'active_support/log_subscriber'

module ActionMailer
  class LogSubscriber < ActiveSupport::LogSubscriber
    def deliver(event)
      info do
        recipients = Array(event.payload[:to]).join(', ')
        "\nSent mail to #{recipients} (#{event.duration.round(1)}ms)"
      end

      debug { event.payload[:mail] }
    end

    def receive(event)
      info { "\nReceived mail (#{event.duration.round(1)}ms)" }
      debug { event.payload[:mail] }
    end

    def process(event)
      debug do
        mailer = event.payload[:mailer]
        action = event.payload[:action]
        "\n#{mailer}##{action}: processed outbound mail in #{event.duration.round(1)}ms"
      end
    end

    def logger
      ActionMailer::Base.logger
    end
  end
end

ActionMailer::LogSubscriber.attach_to :action_mailer
