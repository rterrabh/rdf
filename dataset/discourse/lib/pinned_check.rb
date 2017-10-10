class PinnedCheck

  def self.unpinned?(topic,topic_user=nil)
    topic.pinned_at &&
    topic_user &&
    topic_user.cleared_pinned_at &&
    topic_user.cleared_pinned_at > topic.pinned_at
  end

  def self.pinned?(topic, topic_user=nil)
    !!topic.pinned_at &&
    !unpinned?(topic,topic_user)
  end

end
