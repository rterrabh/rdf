require_dependency 'enum'

class PostActionType < ActiveRecord::Base
  class << self
    def ordered
      order('position asc')
    end

    def types
      @types ||= Enum.new(:bookmark,
                          :like,
                          :off_topic,
                          :inappropriate,
                          :vote,
                          :notify_user,
                          :notify_moderators,
                          :spam)
    end

    def auto_action_flag_types
      @auto_action_flag_types ||= flag_types.except(:notify_user, :notify_moderators)
    end

    def public_types
      @public_types ||= types.except(*flag_types.keys << :notify_user)
    end

    def public_type_ids
      @public_type_ids ||= public_types.values
    end

    def flag_types
      @flag_types ||= types.only(:off_topic, :spam, :inappropriate, :notify_moderators)
    end

    def notify_flag_type_ids
      @notify_flag_type_ids ||= types.only(:off_topic, :spam, :inappropriate, :notify_moderators).values
    end

    def topic_flag_types
      @topic_flag_types ||= types.only(:spam, :inappropriate, :notify_moderators)
    end

    def is_flag?(sym)
      flag_types.valid?(sym)
    end
  end
end

