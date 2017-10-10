
class Postzord::Dispatcher::Private < Postzord::Dispatcher

  def self.salmon(user, activity)
    Salmon::EncryptedSlap.create_by_user_and_activity(user, activity)
  end

  def self.receive_url_for(person)
    person.receive_url
  end
end
