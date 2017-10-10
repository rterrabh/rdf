
module Workers
  class GatherOEmbedData < Base
    sidekiq_options queue: :http_service

    def perform(post_id, url, retry_count=1)
      post = Post.find(post_id)
      post.o_embed_cache = OEmbedCache.find_or_create_by(url: url)
      post.save
    rescue ActiveRecord::RecordNotFound
      GatherOEmbedData.perform_in(1.minute, post_id, url, retry_count+1) unless retry_count > 3
    end
  end
end
