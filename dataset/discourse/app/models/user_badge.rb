class UserBadge < ActiveRecord::Base
  belongs_to :badge
  belongs_to :user
  belongs_to :granted_by, class_name: 'User'
  belongs_to :notification, dependent: :destroy
  belongs_to :post

  validates :badge_id, presence: true, uniqueness: {scope: :user_id}, if: 'badge.single_grant?'
  validates :user_id, presence: true
  validates :granted_at, presence: true
  validates :granted_by, presence: true

  after_create do
    Badge.increment_counter 'grant_count', self.badge_id
    DiscourseEvent.trigger(:user_badge_granted, self.badge_id, self.user_id)
  end

  after_destroy do
    Badge.decrement_counter 'grant_count', self.badge_id
    DiscourseEvent.trigger(:user_badge_removed, self.badge_id, self.user_id)
  end
end

