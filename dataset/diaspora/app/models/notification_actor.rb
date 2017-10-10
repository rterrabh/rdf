
class NotificationActor < ActiveRecord::Base

  belongs_to :notification
  belongs_to :person

end
