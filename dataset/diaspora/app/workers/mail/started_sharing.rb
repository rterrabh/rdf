

module Workers
  module Mail
    class StartedSharing < Base
      sidekiq_options queue: :mail
      
      def perform(recipient_id, sender_id, target_id)
        Notifier.started_sharing(recipient_id, sender_id).deliver_now
      end
    end
  end
end

