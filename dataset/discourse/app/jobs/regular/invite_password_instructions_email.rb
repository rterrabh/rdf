require_dependency 'email/sender'

module Jobs

  class InvitePasswordInstructionsEmail < Jobs::Base

    def execute(args)
      raise Discourse::InvalidParameters.new(:username) unless args[:username].present?
      user = User.find_by_username_or_email(args[:username])
      message = InviteMailer.send_password_instructions(user)
      #nodyna <send-416> <not yet classified>
      Email::Sender.new(message, :invite_password_instructions).send
    end

  end

end
