

module Workers
  class Receive < Base
    sidekiq_options queue: :receive

    def perform(user_id, xml, salmon_author_id)
      suppress_annoying_errors do
        user = User.find(user_id)
        salmon_author = Person.find(salmon_author_id)
        zord = Postzord::Receiver::Private.new(user, :person => salmon_author)
        zord.parse_and_receive(xml)
      end
    end
  end
end
