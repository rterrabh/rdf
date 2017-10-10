
module Workers
  class FetchWebfinger < Base
    sidekiq_options queue: :socket_webfinger

    def perform(account)
      person = Webfinger.new(account).fetch

      Diaspora::Fetcher::Public.queue_for(person) unless person.nil?
    end
  end
end
