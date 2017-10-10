class QuotedPost < ActiveRecord::Base
  belongs_to :post
  belongs_to :quoted_post, class_name: 'Post'

  def self.extract_from(post)

    doc = Nokogiri::HTML.fragment(post.cooked)

    uniq = {}
    ids = []

    doc.css("aside.quote[data-topic]").each do |a|
      topic_id = a['data-topic'].to_i
      post_number = a['data-post'].to_i

      next if topic_id == 0 || post_number == 0
      next if uniq[[topic_id,post_number]]
      uniq[[topic_id,post_number]] = true


      results = exec_sql "INSERT INTO quoted_posts(post_id, quoted_post_id, created_at, updated_at)
               SELECT :post_id, p.id, current_timestamp, current_timestamp
               FROM posts p
               LEFT JOIN quoted_posts q on q.post_id = :post_id AND q.quoted_post_id = p.id
               WHERE post_number = :post_number AND
                     topic_id = :topic_id AND
                     q.id IS NULL
               RETURNING quoted_post_id
      ", post_id: post.id, post_number: post_number, topic_id: topic_id

      results = results.to_a

      if results.length > 0
        ids << results[0]["quoted_post_id"].to_i
      end
    end

    if ids.length > 0
      exec_sql "DELETE FROM quoted_posts WHERE post_id = :post_id AND quoted_post_id NOT IN (:ids)",
          post_id: post.id, ids: ids
    end

    reply_quoted = false

    if post.reply_to_post_number
      reply_post_id = Post.where(topic_id: post.topic_id, post_number: post.reply_to_post_number).pluck(:id).first
      reply_quoted = !!(reply_post_id && ids.include?(reply_post_id))
    end

    if reply_quoted != post.reply_quoted
      post.update_columns(reply_quoted: reply_quoted)
    end

  end
end

