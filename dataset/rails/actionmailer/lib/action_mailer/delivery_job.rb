require 'active_job'

module ActionMailer
  # The <tt>ActionMailer::DeliveryJob</tt> class is used when you
  # want to send emails outside of the request-response cycle.
  class DeliveryJob < ActiveJob::Base # :nodoc:
    queue_as :mailers

    def perform(mailer, mail_method, delivery_method, *args) # :nodoc:
      #nodyna <ID:send-2> <send VERY HIGH ex3>
      #nodyna <ID:send-2> <send VERY HIGH ex3>
      mailer.constantize.public_send(mail_method, *args).send(delivery_method)
    end
  end
end