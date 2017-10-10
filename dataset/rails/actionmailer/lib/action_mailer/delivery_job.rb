require 'active_job'

module ActionMailer
  class DeliveryJob < ActiveJob::Base # :nodoc:
    queue_as :mailers

    def perform(mailer, mail_method, delivery_method, *args) # :nodoc:
      #nodyna <send-1183> <SD COMPLEX (change-prone variables)>
      #nodyna <send-1184> <SD COMPLEX (change-prone variables)>
      mailer.constantize.public_send(mail_method, *args).send(delivery_method)
    end
  end
end
