require_dependency 'oneboxer'

class PostAnalyzer

  def initialize(raw, topic_id)
    @raw  = raw
    @topic_id = topic_id
  end

  def cook(*args)
    cooked = PrettyText.cook(*args)

    result = Oneboxer.apply(cooked) do |url, _|
      Oneboxer.invalidate(url) if args.last[:invalidate_oneboxes]
      Oneboxer.cached_onebox url
    end

    cooked = result.to_html if result.changed?
    cooked
  end

  def image_count
    return 0 unless @raw.present?

    cooked_document.search("img").reject do |t|
      dom_class = t["class"]
      if dom_class
        (Post.white_listed_image_classes & dom_class.split(" ")).count > 0
      end
    end.count
  end

  def attachment_count
    return 0 unless @raw.present?

    attachments = cooked_document.css("a.attachment[href^=\"#{Discourse.store.absolute_base_url}\"]")
    attachments += cooked_document.css("a.attachment[href^=\"#{Discourse.store.relative_base_url}\"]") if Discourse.store.internal?
    attachments.count
  end

  def raw_mentions
    return [] if @raw.blank?
    return @raw_mentions if @raw_mentions.present?

    cooked_stripped = cooked_document
    cooked_stripped.css("aside.quote").remove
    cooked_stripped.css("pre").remove
    cooked_stripped.css("code").remove
    cooked_stripped.css(".onebox").remove

    results = cooked_stripped.to_html.scan(PrettyText.mention_matcher)
    @raw_mentions = results.uniq.map { |un| un.first.downcase.gsub!(/^@/, '') }
  end

  def self.parse_uri_rfc2396(uri)
    @parser ||= defined?(URI::RFC2396_Parser) ? URI::RFC2396_Parser.new : URI
    @parser.parse(uri)
  end

  def linked_hosts
    return {} if raw_links.blank?
    return @linked_hosts if @linked_hosts.present?

    @linked_hosts = {}

    raw_links.each do |u|
      begin
        uri = self.class.parse_uri_rfc2396(u)
        host = uri.host
        @linked_hosts[host] ||= 1 unless host.nil?
      rescue URI::InvalidURIError
        next
      end
    end

    @linked_hosts
  end

  def raw_links
    return [] unless @raw.present?
    return @raw_links if @raw_links.present?

    @raw_links = []

    cooked_document.search("a").each do |l|
      next if l.attributes['href'].nil? || link_is_a_mention?(l)
      url = l.attributes['href'].to_s
      @raw_links << url
    end

    @raw_links
  end

  def link_count
    raw_links.size
  end

  private

  def cooked_document
    @cooked_document ||= Nokogiri::HTML.fragment(cook(@raw, topic_id: @topic_id))
  end

  def link_is_a_mention?(l)
    html_class = l.attributes['class']
    return false if html_class.nil?
    html_class.to_s == 'mention' && l.attributes['href'].to_s =~ /^\/users\//
  end
end
