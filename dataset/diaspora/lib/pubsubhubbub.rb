

class Pubsubhubbub
  def initialize(hub, options={})
    @hub = hub
  end

  def publish(feed)

    conn = Faraday.new do |c|
      c.use Faraday::Request::UrlEncoded  # encode request params as "www-form-urlencoded"
      c.use Faraday::Adapter::NetHttp     # perform requests with Net::HTTP
    end
    conn.post @hub, {'hub.url' => feed, 'hub.mode' => 'publish'}
  end
end
