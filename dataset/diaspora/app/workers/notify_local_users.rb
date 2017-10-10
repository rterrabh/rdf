
module Workers
  class NotifyLocalUsers < Base
    sidekiq_options queue: :receive_local

    def perform(user_ids, object_klass, object_id, person_id)

      object = object_klass.constantize.find_by_id(object_id)

      users = User.where(:id => user_ids)
      person = Person.find_by_id(person_id)

      users.find_each{|user| Notification.notify(user, object, person) }
    end
  end
end
