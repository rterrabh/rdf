

module Workers
  module Mail
    class PrivateMessage < Base
      sidekiq_options queue: :mail
      
      def perform(recipient_id, actor_id, target_id)
        Notifier.private_message( recipient_id, actor_id, target_id).deliver_now
      end
    end
  end
end
