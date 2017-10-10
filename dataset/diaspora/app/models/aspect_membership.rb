
class AspectMembership < ActiveRecord::Base

  belongs_to :aspect
  belongs_to :contact
  has_one :user, :through => :contact
  has_one :person, :through => :contact

  before_destroy do
    if self.contact && self.contact.aspects.size == 1
      self.user.disconnect(self.contact)
    end
    true
  end

  def as_json(opts={})
    {
      :id => self.id,
      :person_id  => self.person.id,
      :contact_id => self.contact.id,
      :aspect_id  => self.aspect_id,
      :aspect_ids => self.contact.aspects.map{|a| a.id}
    }
  end
end
