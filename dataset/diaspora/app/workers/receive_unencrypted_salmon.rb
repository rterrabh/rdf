
module Workers
  class ReceiveUnencryptedSalmon < Base
    sidekiq_options queue: :receive

    def perform(xml)
      suppress_annoying_errors do
        receiver = Postzord::Receiver::Public.new(xml)
        receiver.perform!
      end
    end
  end
end
