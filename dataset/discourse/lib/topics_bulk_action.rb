class TopicsBulkAction

  def initialize(user, topic_ids, operation)
    @user = user
    @topic_ids = topic_ids
    @operation = operation
    @changed_ids = []
  end

  def self.operations
    @operations ||= %w(change_category close archive change_notification_level reset_read dismiss_posts delete)
  end

  def self.register_operation(name, &block)
    operations << name
    #nodyna <ID:define_method-5> <DM COMPLEX (events)>
    define_method(name, &block)
  end

  def perform!
    raise Discourse::InvalidParameters.new(:operation) unless TopicsBulkAction.operations.include?(@operation[:type])
    #nodyna <ID:send-21> <SD COMPLEX (change-prone variables)>
    send(@operation[:type])
    @changed_ids
  end

  private

    def dismiss_posts
      sql = "
      UPDATE topic_users tu
      SET highest_seen_post_number = t.highest_post_number , last_read_post_number = highest_post_number
      FROM topics t
      WHERE t.id = tu.topic_id AND tu.user_id = :user_id AND t.id IN (:topic_ids)
      "

      Topic.exec_sql(sql, user_id: @user.id, topic_ids: @topic_ids)
      @changed_ids.concat @topic_ids
    end

    def reset_read
      PostTiming.destroy_for(@user.id, @topic_ids)
    end

    def change_category
      topics.each do |t|
        if guardian.can_edit?(t)
          @changed_ids << t.id if t.change_category_to_id(@operation[:category_id])
        end
      end
    end

    def change_notification_level
      topics.each do |t|
        if guardian.can_see?(t)
          TopicUser.change(@user, t.id, notification_level: @operation[:notification_level_id].to_i)
          @changed_ids << t.id
        end
      end
    end

    def close
      topics.each do |t|
        if guardian.can_moderate?(t)
          t.update_status('closed', true, @user)
          @changed_ids << t.id
        end
      end
    end

    def archive
      topics.each do |t|
        if guardian.can_moderate?(t)
          t.update_status('archived', true, @user)
          @changed_ids << t.id
        end
      end
    end

    def delete
      topics.each do |t|
        t.trash! if guardian.can_delete?(t)
      end
    end

    def guardian
      @guardian ||= Guardian.new(@user)
    end

    def topics
      @topics ||= Topic.where(id: @topic_ids)
    end


end

