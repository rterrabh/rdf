
class Like < Federated::Relayable
  class Generator < Federated::Generator
    def self.federated_class
      Like
    end

    def relayable_options
      {:target => @target, :positive => true}
    end
  end

  after_commit :on => :create do
    self.parent.update_likes_counter
  end

  after_destroy do
    self.parent.update_likes_counter
  end

  xml_attr :positive

  acts_as_api
  api_accessible :backbone do |t|
    t.add :id
    t.add :guid
    t.add :author
    t.add :created_at
  end

  def notification_type(user, person)
    return nil if self.target_type == "Comment"
    Notifications::Liked if self.target.author == user.person && user.person != person
  end
end
