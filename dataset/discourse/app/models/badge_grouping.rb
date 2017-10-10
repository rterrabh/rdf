class BadgeGrouping < ActiveRecord::Base

  GettingStarted = 1
  Community = 2
  Posting = 3
  TrustLevel = 4
  Other = 5

  has_many :badges

  def system?
    id && id < 5
  end

  def default_position=(pos)
    self.position ||= pos
  end
end

