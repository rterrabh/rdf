module Workers
  class DeletePostFromService < Base
    sidekiq_options queue: :http_service

    def perform(service_id, post_id)
      service = Service.find_by_id(service_id)
      post = Post.find_by_id(post_id)
      service.delete_post(post)
    end
  end
end
