

module Workers
  module Mail
    class Mentioned < Base
      sidekiq_options queue: :mail
      
      def perform(recipient_id, actor_id, target_id)
        Notifier.mentioned( recipient_id, actor_id, target_id).deliver_now
      end
    end
  end
end
