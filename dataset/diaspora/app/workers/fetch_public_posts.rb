
module Workers
  class FetchPublicPosts < Base
    sidekiq_options queue: :http_service

    def perform(diaspora_id)
      Diaspora::Fetcher::Public.new.fetch!(diaspora_id)
    end
  end
end
