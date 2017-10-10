class TopicUser < ActiveRecord::Base
  belongs_to :user
  belongs_to :topic

  attr_accessor :post_action_data

  scope :tracking, lambda { |topic_id|
    where(topic_id: topic_id)
   .where("COALESCE(topic_users.notification_level, :regular) >= :tracking",
     regular: TopicUser.notification_levels[:regular],
     tracking: TopicUser.notification_levels[:tracking])
  }

  class << self

    def notification_levels
      @notification_levels ||= Enum.new(:muted, :regular, :tracking, :watching, start: 0)
    end

    def notification_reasons
      @notification_reasons ||= Enum.new(
        :created_topic,
        :user_changed,
        :user_interacted,
        :created_post,
        :auto_watch,
        :auto_watch_category,
        :auto_mute_category,
        :auto_track_category,
        :plugin_changed
      )
    end

    def auto_track(user_id, topic_id, reason)
      if TopicUser.where(user_id: user_id, topic_id: topic_id, notifications_reason_id: nil).exists?
        change(user_id, topic_id,
          notification_level: notification_levels[:tracking],
          notifications_reason_id: reason
        )

        MessageBus.publish("/topic/#{topic_id}", {
          notification_level_change: notification_levels[:tracking],
          notifications_reason_id: reason
        }, user_ids: [user_id])
      end
    end

    def lookup_for(user, topics)
      return {} if user.blank? || topics.blank?

      topic_ids = topics.map(&:id)
      create_lookup(TopicUser.where(topic_id: topic_ids, user_id: user.id))
    end

    def create_lookup(topic_users)
      topic_users = topic_users.to_a
      result = {}
      return result if topic_users.blank?
      topic_users.each { |ftu| result[ftu.topic_id] = ftu }
      result
    end

    def get(topic, user)
      topic = topic.id if topic.is_a?(Topic)
      user = user.id if user.is_a?(User)
      TopicUser.find_by(topic_id: topic, user_id: user)
    end

    def change(user_id, topic_id, attrs)
      topic_id = topic_id.id if topic_id.is_a?(::Topic)
      user_id = user_id.id if user_id.is_a?(::User)

      topic_id = topic_id.to_i
      user_id = user_id.to_i

      TopicUser.transaction do
        attrs = attrs.dup
        if attrs[:notification_level]
          attrs[:notifications_changed_at] ||= DateTime.now
          attrs[:notifications_reason_id] ||= TopicUser.notification_reasons[:user_changed]
        end
        attrs_array = attrs.to_a

        attrs_sql = attrs_array.map { |t| "#{t[0]} = ?" }.join(", ")
        vals = attrs_array.map { |t| t[1] }
        rows = TopicUser.where(topic_id: topic_id, user_id: user_id).update_all([attrs_sql, *vals])

        if rows == 0
          now = DateTime.now
          auto_track_after = User.select(:auto_track_topics_after_msecs).find_by(id: user_id).auto_track_topics_after_msecs
          auto_track_after ||= SiteSetting.default_other_auto_track_topics_after_msecs

          if auto_track_after >= 0 && auto_track_after <= (attrs[:total_msecs_viewed] || 0)
            attrs[:notification_level] ||= notification_levels[:tracking]
          end

          TopicUser.create(attrs.merge!(user_id: user_id, topic_id: topic_id, first_visited_at: now ,last_visited_at: now))
        else
          observe_after_save_callbacks_for topic_id, user_id
        end
      end

      if attrs[:notification_level]
        MessageBus.publish("/topic/#{topic_id}", { notification_level_change: attrs[:notification_level] }, user_ids: [user_id])
      end

    rescue ActiveRecord::RecordNotUnique
    end

    def track_visit!(topic,user)
      topic_id = topic.is_a?(Topic) ? topic.id : topic
      user_id = user.is_a?(User) ? user.id : topic

      now = DateTime.now
      rows = TopicUser.where(topic_id: topic_id, user_id: user_id).update_all(last_visited_at: now)
      if rows == 0
        TopicUser.create(topic_id: topic_id, user_id: user_id, last_visited_at: now, first_visited_at: now)
      else
        observe_after_save_callbacks_for topic_id, user_id
      end
    end

    def update_last_read(user, topic_id, post_number, msecs, opts={})
      return if post_number.blank?
      msecs = 0 if msecs.to_i < 0

      args = {
        user_id: user.id,
        topic_id: topic_id,
        post_number: post_number,
        now: DateTime.now,
        msecs: msecs,
        tracking: notification_levels[:tracking],
        threshold: SiteSetting.default_other_auto_track_topics_after_msecs
      }

      rows = exec_sql("UPDATE topic_users
                                    SET
                                      last_read_post_number = GREATEST(:post_number, tu.last_read_post_number),
                                      highest_seen_post_number = t.highest_post_number,
                                      total_msecs_viewed = LEAST(tu.total_msecs_viewed + :msecs,86400000),
                                      notification_level =
                                         case when tu.notifications_reason_id is null and (tu.total_msecs_viewed + :msecs) >
                                            coalesce(u.auto_track_topics_after_msecs,:threshold) and
                                            coalesce(u.auto_track_topics_after_msecs, :threshold) >= 0 then
                                              :tracking
                                         else
                                            tu.notification_level
                                         end
                                  FROM topic_users tu
                                  join topics t on t.id = tu.topic_id
                                  join users u on u.id = :user_id
                                  WHERE
                                       tu.topic_id = topic_users.topic_id AND
                                       tu.user_id = topic_users.user_id AND
                                       tu.topic_id = :topic_id AND
                                       tu.user_id = :user_id
                                  RETURNING
                                    topic_users.notification_level, tu.notification_level old_level, tu.last_read_post_number
                                ",
                                args).values

      if rows.length == 1
        before = rows[0][1].to_i
        after = rows[0][0].to_i

        before_last_read = rows[0][2].to_i

        if before_last_read < post_number
          TopicTrackingState.publish_read(topic_id, post_number, user.id, after)
          user.update_posts_read!(post_number - before_last_read, mobile: opts[:mobile])
        end

        if before != after
          MessageBus.publish("/topic/#{topic_id}", { notification_level_change: after }, user_ids: [user.id])
        end
      end

      if rows.length == 0
        args[:new_status] = notification_levels[:regular]
        if (user.auto_track_topics_after_msecs || SiteSetting.default_other_auto_track_topics_after_msecs) == 0
          args[:new_status] = notification_levels[:tracking]
        end
        TopicTrackingState.publish_read(topic_id, post_number, user.id, args[:new_status])

        user.update_posts_read!(post_number, mobile: opts[:mobile])

        exec_sql("INSERT INTO topic_users (user_id, topic_id, last_read_post_number, highest_seen_post_number, last_visited_at, first_visited_at, notification_level)
                  SELECT :user_id, :topic_id, :post_number, ft.highest_post_number, :now, :now, :new_status
                  FROM topics AS ft
                  JOIN users u on u.id = :user_id
                  WHERE ft.id = :topic_id
                    AND NOT EXISTS(SELECT 1
                                   FROM topic_users AS ftu
                                   WHERE ftu.user_id = :user_id and ftu.topic_id = :topic_id)",
                  args)

        MessageBus.publish("/topic/#{topic_id}", { notification_level_change: args[:new_status] }, user_ids: [user.id])
      end
    end

    def observe_after_save_callbacks_for(topic_id, user_id)
      TopicUser.where(topic_id: topic_id, user_id: user_id).each do |topic_user|
        UserActionObserver.instance.after_save topic_user
      end
    end
  end

  def self.update_post_action_cache(opts={})
    user_id = opts[:user_id]
    post_id = opts[:post_id]
    topic_id = opts[:topic_id]
    action_type = opts[:post_action_type]

    action_type_name = "liked" if action_type == :like
    action_type_name = "bookmarked" if action_type == :bookmark

    raise ArgumentError, "action_type" if action_type && !action_type_name

    unless action_type_name
      update_post_action_cache(opts.merge(post_action_type: :like))
      update_post_action_cache(opts.merge(post_action_type: :bookmark))
      return
    end

    builder = SqlBuilder.new <<SQL
    UPDATE topic_users tu
    SET #{action_type_name} = x.state
    FROM (
      SELECT CASE WHEN EXISTS (
        SELECT 1
        FROM post_actions pa
        JOIN posts p on p.id = pa.post_id
        JOIN topics t ON t.id = p.topic_id
        WHERE pa.deleted_at IS NULL AND
              p.deleted_at IS NULL AND
              t.deleted_at IS NULL AND
              pa.post_action_type_id = :action_type_id AND
              tu2.topic_id = t.id AND
              tu2.user_id = pa.user_id
        LIMIT 1
      ) THEN true ELSE false END state, tu2.topic_id, tu2.user_id
      FROM topic_users tu2
      /*where*/
    ) x
    WHERE x.topic_id = tu.topic_id AND x.user_id = tu.user_id AND x.state != tu.#{action_type_name}
SQL

    if user_id
      builder.where("tu2.user_id = :user_id", user_id: user_id)
    end

    if topic_id
      builder.where("tu2.topic_id = :topic_id", topic_id: topic_id)
    end

    if post_id
      builder.where("tu2.topic_id IN (SELECT topic_id FROM posts WHERE id = :post_id)", post_id: post_id)
      builder.where("tu2.user_id IN (SELECT user_id FROM post_actions
                                     WHERE post_id = :post_id AND
                                           post_action_type_id = :action_type_id)")
    end

    builder.exec(action_type_id: PostActionType.types[action_type])
  end

  def self.ensure_consistency!(topic_id=nil)
    update_post_action_cache(topic_id: topic_id)

    builder = SqlBuilder.new <<SQL

UPDATE topic_users t
  SET
    last_read_post_number = LEAST(GREATEST(last_read, last_read_post_number), max_post_number),
    highest_seen_post_number = LEAST(max_post_number,GREATEST(t.highest_seen_post_number, last_read))
FROM (
  SELECT topic_id, user_id, MAX(post_number) last_read
  FROM post_timings
  GROUP BY topic_id, user_id
) as X
JOIN (
  SELECT p.topic_id, MAX(p.post_number) max_post_number from posts p
  GROUP BY p.topic_id
) as Y on Y.topic_id = X.topic_id
/*where*/
SQL

    builder.where <<SQL
X.topic_id = t.topic_id AND
X.user_id = t.user_id AND
(
  last_read_post_number <> LEAST(GREATEST(last_read, last_read_post_number), max_post_number) OR
  highest_seen_post_number <> LEAST(max_post_number,GREATEST(t.highest_seen_post_number, last_read))
)
SQL

    if topic_id
      builder.where("t.topic_id = :topic_id", topic_id: topic_id)
    end

    builder.exec
  end

end

