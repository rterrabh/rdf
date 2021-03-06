class CategoryUser < ActiveRecord::Base
  belongs_to :category
  belongs_to :user

  def self.lookup(user, level)
    self.where(user: user, notification_level: notification_levels[level])
  end

  def self.lookup_by_category(user, category)
    self.where(user: user, category: category)
  end

  def self.notification_levels
    TopicUser.notification_levels
  end

  %w{watch track}.each do |s|
    define_singleton_method("auto_#{s}_new_topic") do |topic, new_category=nil|
      category_id = topic.category_id

      if new_category && topic.created_at > 5.days.ago
        category_id = new_category.id
        remove_default_from_topic(topic.id, TopicUser.notification_levels[:"#{s}ing"], TopicUser.notification_reasons[:"auto_#{s}_category"])
      end

      apply_default_to_topic(topic.id, category_id, TopicUser.notification_levels[:"#{s}ing"], TopicUser.notification_reasons[:"auto_#{s}_category"])
    end
  end

  def self.batch_set(user, level, category_ids)
    records = CategoryUser.where(user: user, notification_level: notification_levels[level])
    old_ids = records.pluck(:category_id)

    category_ids = Category.where('id in (?)', category_ids).pluck(:id)

    remove = (old_ids - category_ids)
    if remove.present?
      records.where('category_id in (?)', remove).destroy_all
    end

    (category_ids - old_ids).each do |id|
      CategoryUser.create!(user: user, category_id: id, notification_level: notification_levels[level])
    end
  end

  def self.set_notification_level_for_category(user, level, category_id)
    record = CategoryUser.where(user: user, category_id: category_id).first

    if record.present?
      record.notification_level = level
      record.save!
    else
      CategoryUser.create!(user: user, category_id: category_id, notification_level: level)
    end
  end

  def self.apply_default_to_topic(topic_id, category_id, level, reason)
    sql = <<-SQL
      INSERT INTO topic_users(user_id, topic_id, notification_level, notifications_reason_id)
           SELECT user_id, :topic_id, :level, :reason
             FROM category_users
            WHERE notification_level = :level
              AND category_id = :category_id
              AND NOT EXISTS(SELECT 1 FROM topic_users WHERE topic_id = :topic_id AND user_id = category_users.user_id)
    SQL

    exec_sql(sql,
      topic_id: topic_id,
      category_id: category_id,
      level: level,
      reason: reason
    )
  end

  def self.remove_default_from_topic(topic_id, level, reason)
    sql = <<-SQL
      DELETE FROM topic_users
            WHERE topic_id = :topic_id
              AND notifications_changed_at IS NULL
              AND notification_level = :level
              AND notifications_reason_id = :reason
    SQL

    exec_sql(sql,
      topic_id: topic_id,
      level: level,
      reason: reason
    )
  end

  private_class_method :apply_default_to_topic, :remove_default_from_topic
end

