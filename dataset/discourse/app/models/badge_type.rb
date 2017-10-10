class BadgeType < ActiveRecord::Base
  Gold = 1
  Silver = 2
  Bronze = 3


  has_many :badges
  validates :name, presence: true, uniqueness: true
end

