
class Postzord::Dispatcher::Public < Postzord::Dispatcher

  def self.salmon(user, activity)
    Salmon::Slap.create_by_user_and_activity(user, activity)
  end

  def self.receive_url_for(person)
    person.url + 'receive/public'
  end
end
