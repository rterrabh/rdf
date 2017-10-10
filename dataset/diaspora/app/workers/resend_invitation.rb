

module Workers
  class ResendInvitation < Base
    sidekiq_options queue: :mail
    
    def perform(invitation_id)
      inv = Invitation.find(invitation_id)
      inv.resend
    end
  end
end
