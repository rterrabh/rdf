
module Diaspora::Guid
  def self.included(model)
    #nodyna <class_eval-214> <not yet classified>
    model.class_eval do
      after_initialize :set_guid
      xml_attr :guid
      validates :guid, :uniqueness => true

    end
  end

  def set_guid
    self.guid = UUID.generate :compact if self.guid.blank?
  end
end
