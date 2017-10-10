class TopicRetriever

  def initialize(embed_url, opts=nil)
    @embed_url = embed_url
    @author_username = opts[:author_username]
    @opts = opts || {}
  end

  def retrieve
    perform_retrieve unless (invalid_host? || retrieved_recently?)
  end

  private

    def invalid_host?
      !EmbeddableHost.host_allowed?(@embed_url)
    end

    def retrieved_recently?
      return false if @opts[:no_throttle]

      retrieved_key = "retrieved:#{@embed_url}"
      if $redis.setnx(retrieved_key, "1")
        $redis.expire(retrieved_key, 60)
        return false
      end

      true
    end

    def perform_retrieve
      return if TopicEmbed.where(embed_url: @embed_url).exists?

      if SiteSetting.feed_polling_enabled?
        Jobs::PollFeed.new.execute({})
        return if TopicEmbed.where(embed_url: @embed_url).exists?
      end

      fetch_http
    end

    def fetch_http
      if @author_username.nil?
        username = SiteSetting.embed_by_username.downcase
      else
        username = @author_username
      end

      user = User.where(username_lower: username.downcase).first
      return if user.blank?

      TopicEmbed.import_remote(user, @embed_url)
    end

end
