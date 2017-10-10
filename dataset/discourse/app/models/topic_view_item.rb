require 'ipaddr'

class TopicViewItem < ActiveRecord::Base
  self.table_name = 'topic_views'
  belongs_to :user
  validates_presence_of :topic_id, :ip_address, :viewed_at

  def self.add(topic_id, ip, user_id=nil, at=nil, skip_redis=false)
    redis_key = "view:#{topic_id}:#{Date.today}"
    if user_id
      redis_key << ":user-#{user_id}"
    else
      redis_key << ":ip-#{ip}"
    end

    if skip_redis || $redis.setnx(redis_key, "1")
      skip_redis || $redis.expire(redis_key, SiteSetting.topic_view_duration_hours.hours)

      TopicViewItem.transaction do
        at ||= Date.today

        sql = "INSERT INTO topic_views (topic_id, ip_address, viewed_at, user_id)
               SELECT :topic_id, :ip_address, :viewed_at, :user_id
               WHERE NOT EXISTS (
                 SELECT 1 FROM topic_views
                 /*where*/
               )"


        builder = SqlBuilder.new(sql)

        if !user_id
          builder.where("ip_address = :ip_address AND topic_id = :topic_id AND user_id IS NULL")
        else
          builder.where("user_id = :user_id AND topic_id = :topic_id")
        end

        result = builder.exec(topic_id: topic_id, ip_address: ip, viewed_at: at, user_id: user_id)

        Topic.where(id: topic_id).update_all 'views = views + 1'

        if result.cmd_tuples > 0
          UserStat.where(user_id: user_id).update_all 'topics_entered = topics_entered + 1' if user_id
        end

      end
    end
  end

end

