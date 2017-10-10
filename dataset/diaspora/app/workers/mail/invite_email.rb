
module Workers
  module Mail
    class InviteEmail < Base
      sidekiq_options queue: :mail

      def perform(emails, inviter_id, options={})
        #nodyna <send-227> <not yet classified>
        EmailInviter.new(emails, User.find(inviter_id), options).send!
      end
    end
  end
end
