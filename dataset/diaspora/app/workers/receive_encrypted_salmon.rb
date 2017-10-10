

module Workers
  class ReceiveEncryptedSalmon < Base
    sidekiq_options queue: :receive_salmon

    def perform(user_id, xml)
      suppress_annoying_errors do
        user = User.find(user_id)
        zord = Postzord::Receiver::Private.new(user, :salmon_xml => xml)
        zord.perform!
      end
    end
  end
end

