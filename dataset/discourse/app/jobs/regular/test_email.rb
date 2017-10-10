require_dependency 'email/sender'

module Jobs

  class TestEmail < Jobs::Base

    def execute(args)

      raise Discourse::InvalidParameters.new(:to_address) unless args[:to_address].present?

      message = TestMailer.send_test(args[:to_address])
      #nodyna <send-413> <not yet classified>
      Email::Sender.new(message, :test_message).send
    end

  end

end
