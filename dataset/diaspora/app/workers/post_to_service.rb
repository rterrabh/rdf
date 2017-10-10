module Workers
  class PostToService < Base
    sidekiq_options queue: :http_service

    def perform(service_id, post_id, url)
      service = Service.find_by_id(service_id)
      post = Post.find_by_id(post_id)
      service.post(post, url)
    end
  end
end
