
module Workers
  class ReceiveLocalBatch < Base
    sidekiq_options queue: :receive

    def perform(object_class_string, object_id, recipient_user_ids)
      object = object_class_string.constantize.find(object_id)
      receiver = Postzord::Receiver::LocalBatch.new(object, recipient_user_ids)
      receiver.perform!
    rescue ActiveRecord::RecordNotFound # Already deleted before the job could run
    end
  end
end
