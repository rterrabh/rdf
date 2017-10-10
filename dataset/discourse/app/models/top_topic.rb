class TopTopic < ActiveRecord::Base

  belongs_to :topic

  def self.refresh_daily!
    transaction do
      remove_invisible_topics
      add_new_visible_topics

      update_counts_and_compute_scores_for(:daily)
    end
  end

  def self.refresh_older!
    older_periods = periods - [:daily,:all]

    transaction do
      older_periods.each do |period|
        update_counts_and_compute_scores_for(period)
      end
    end

    compute_top_score_for(:all)
  end

  def self.refresh!
    refresh_daily!
    refresh_older!
  end


  def self.periods
    @@periods ||= [:all, :yearly, :quarterly, :monthly, :weekly, :daily].freeze
  end

  def self.sort_orders
    @@sort_orders ||= [:posts, :views, :likes, :op_likes].freeze
  end

  def self.update_counts_and_compute_scores_for(period)
    sort_orders.each do |sort|
      #nodyna <send-387> <SD MODERATE (array)>
      TopTopic.send("update_#{sort}_count_for", period)
    end
    compute_top_score_for(period)
  end

  def self.remove_invisible_topics
    exec_sql("WITH category_definition_topic_ids AS (
                  SELECT COALESCE(topic_id, 0) AS id FROM categories
                ), invisible_topic_ids AS (
                  SELECT id
                  FROM topics
                  WHERE deleted_at IS NOT NULL
                     OR NOT visible
                     OR archetype = :private_message
                     OR archived
                     OR id IN (SELECT id FROM category_definition_topic_ids)
                )
                DELETE FROM top_topics
                WHERE topic_id IN (SELECT id FROM invisible_topic_ids)",
             private_message: Archetype::private_message)
  end

  def self.add_new_visible_topics
    exec_sql("WITH category_definition_topic_ids AS (
                  SELECT COALESCE(topic_id, 0) AS id FROM categories
                ), visible_topics AS (
                SELECT t.id
                FROM topics t
                LEFT JOIN top_topics tt ON t.id = tt.topic_id
                WHERE t.deleted_at IS NULL
                  AND t.visible
                  AND t.archetype <> :private_message
                  AND NOT t.archived
                  AND t.id NOT IN (SELECT id FROM category_definition_topic_ids)
                  AND tt.topic_id IS NULL
              )
              INSERT INTO top_topics (topic_id)
              SELECT id FROM visible_topics",
             private_message: Archetype::private_message)
  end

  def self.update_posts_count_for(period)
    sql = "SELECT topic_id, GREATEST(COUNT(*), 1) AS count
             FROM posts
             WHERE created_at >= :from
               AND deleted_at IS NULL
               AND NOT hidden
               AND post_type = #{Post.types[:regular]}
               AND user_id <> #{Discourse.system_user.id}
             GROUP BY topic_id"

    update_top_topics(period, "posts", sql)
  end

  def self.update_views_count_for(period)
    sql = "SELECT topic_id, COUNT(*) AS count
             FROM topic_views
             WHERE viewed_at >= :from
             GROUP BY topic_id"

    update_top_topics(period, "views", sql)
  end

  def self.update_likes_count_for(period)
    sql = "SELECT topic_id, SUM(like_count) AS count
             FROM posts
             WHERE created_at >= :from
               AND deleted_at IS NULL
               AND NOT hidden
               AND post_type = #{Post.types[:regular]}
             GROUP BY topic_id"

    update_top_topics(period, "likes", sql)
  end

  def self.update_op_likes_count_for(period)
    sql = "SELECT topic_id, like_count AS count
             FROM posts
             WHERE created_at >= :from
               AND post_number = 1
               AND deleted_at IS NULL
               AND NOT hidden
               AND post_type = #{Post.types[:regular]}"

    update_top_topics(period, "op_likes", sql)
  end

  def self.compute_top_score_for(period)

    if period == :all
      top_topics = "(
        SELECT t.like_count all_likes_count,
               t.id topic_id,
               t.posts_count all_posts_count,
               p.like_count all_op_likes_count,
               t.views all_views_count
        FROM topics t
        JOIN posts p ON p.topic_id = t.id AND p.post_number = 1
      ) as top_topics"
      time_filter = "false"
    else
      top_topics = "top_topics"
      time_filter = "topics.created_at < :from"
    end

    sql = <<-SQL
        WITH top AS (
          SELECT CASE
                   WHEN #{time_filter} THEN 0
                   ELSE log(GREATEST(#{period}_views_count, 1)) * 2 +
                        CASE WHEN #{period}_likes_count > 0 AND #{period}_posts_count > 0
                           THEN
                            LEAST(#{period}_likes_count / #{period}_posts_count, 3)
                           ELSE 0
                        END +
                        CASE WHEN topics.posts_count < 10 THEN
                           0 - ((10 - topics.posts_count) / 20) * #{period}_op_likes_count
                        ELSE
                           10
                        END +
                        log(GREATEST(#{period}_posts_count, 1))
                 END AS score,
                 topic_id
          FROM #{top_topics}
          LEFT JOIN topics ON topics.id = top_topics.topic_id AND
                              topics.deleted_at IS NULL
        )
        UPDATE top_topics
        SET #{period}_score = top.score
        FROM top
        WHERE top_topics.topic_id = top.topic_id
          AND #{period}_score <> top.score
    SQL

    exec_sql(sql, from: start_of(period))
  end

  def self.start_of(period)
    case period
      when :yearly    then 1.year.ago
      when :monthly   then 1.month.ago
      when :quarterly then 3.months.ago
      when :weekly    then 1.week.ago
      when :daily     then 1.day.ago
    end
  end

  def self.update_top_topics(period, sort, inner_join)
    exec_sql("UPDATE top_topics
                SET #{period}_#{sort}_count = c.count
                FROM top_topics tt
                INNER JOIN (#{inner_join}) c ON tt.topic_id = c.topic_id
                WHERE tt.topic_id = top_topics.topic_id
                  AND tt.#{period}_#{sort}_count <> c.count",
             from: start_of(period))
  end

  private_class_method :sort_orders, :update_counts_and_compute_scores_for, :remove_invisible_topics,
                       :add_new_visible_topics, :update_posts_count_for, :update_views_count_for, :update_likes_count_for,
                       :compute_top_score_for, :start_of, :update_top_topics
end

