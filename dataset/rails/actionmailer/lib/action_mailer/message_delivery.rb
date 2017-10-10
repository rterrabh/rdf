require 'delegate'
require 'active_support/core_ext/string/filters'

module ActionMailer

  class MessageDelivery < Delegator
    def initialize(mailer, mail_method, *args) #:nodoc:
      @mailer = mailer
      @mail_method = mail_method
      @args = args
    end

    def __getobj__ #:nodoc:
      #nodyna <send-1182> <SD COMPLEX (private methods)>
      @obj ||= @mailer.send(:new, @mail_method, *@args).message
    end

    def __setobj__(obj) #:nodoc:
      @obj = obj
    end

    def message
      __getobj__
    end

    def deliver_later!(options={})
      enqueue_delivery :deliver_now!, options
    end

    def deliver_later(options={})
      enqueue_delivery :deliver_now, options
    end

    def deliver_now!
      message.deliver!
    end

    def deliver_now
      message.deliver
    end

    def deliver! #:nodoc:
      ActiveSupport::Deprecation.warn(<<-MSG.squish)
        `#deliver!` is deprecated and will be removed in Rails 5. Use
        `#deliver_now!` to deliver immediately or `#deliver_later!` to
        deliver through Active Job.
      MSG

      deliver_now!
    end

    def deliver #:nodoc:
      ActiveSupport::Deprecation.warn(<<-MSG.squish)
        `#deliver` is deprecated and will be removed in Rails 5. Use
        `#deliver_now` to deliver immediately or `#deliver_later` to
        deliver through Active Job.
      MSG

      deliver_now
    end

    private

      def enqueue_delivery(delivery_method, options={})
        args = @mailer.name, @mail_method.to_s, delivery_method.to_s, *@args
        ActionMailer::DeliveryJob.set(options).perform_later(*args)
      end
  end
end
