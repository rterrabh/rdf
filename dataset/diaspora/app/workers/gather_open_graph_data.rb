
module Workers
  class GatherOpenGraphData < Base
    sidekiq_options queue: :http_service

    def perform(post_id, url, retry_count=1)
      post = Post.find(post_id)
      post.open_graph_cache = OpenGraphCache.find_or_create_by(url: url)
      post.save
    rescue ActiveRecord::RecordNotFound
      GatherOpenGraphData.perform_in(1.minute, post_id, url, retry_count+1) unless retry_count > 3
    end
  end
end
