
class UsersStarProject < ActiveRecord::Base
  belongs_to :project, counter_cache: :star_count
  belongs_to :user

  validates :user, presence: true
  validates :user_id, uniqueness: { scope: [:project_id] }
  validates :project, presence: true
end
