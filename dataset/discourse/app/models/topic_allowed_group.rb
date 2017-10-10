class TopicAllowedGroup < ActiveRecord::Base
  belongs_to :topic
  belongs_to :group

  validates_uniqueness_of :topic_id, scope: :group_id
end

