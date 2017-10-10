require 'open-uri'
require 'nokogiri'
require 'excon'

module Jobs
  class CrawlTopicLink < Jobs::Base

    class ReadEnough < StandardError; end

    def self.header_for(head, name)
      header = head.headers.detect do |k, _|
        name == k.downcase
      end
      header[1] if header
    end

    def self.request_headers(uri)
      { "User-Agent" => "Mozilla/5.0 (Windows NT 6.2; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/32.0.1667.0 Safari/537.36",
        "Accept" => "text/html",
        "Host" => uri.host }
    end

    def self.final_uri(url, limit=5)
      return if limit < 0

      uri = URI(url)
      return if uri.blank? || uri.host.blank?
      headers = CrawlTopicLink.request_headers(uri)
      head = Excon.head(url, read_timeout: 20, headers: headers)

      return uri if head.status == 405

      if head.status == 200
        uri = nil unless header_for(head, 'content-type') =~ /text\/html/
        return uri
      end

      location = header_for(head, 'location')
      if location
        location = "#{uri.scheme}://#{uri.host}#{location}" if location[0] == "/"
        return final_uri(location, limit - 1)
      end

      nil
    end

    def self.max_chunk_size(uri)
      return 80 if uri.host =~ /amazon\.(com|ca|co\.uk|es|fr|de|it|com\.au|com\.br|cn|in|co\.jp|com\.mx)$/

      10
    end

    def self.fetch_beginning(url)
      return if Rails.env.test?

      uri = final_uri(url)
      return "" unless uri

      result = ""
      streamer = lambda do |chunk, _, _|
        result << chunk

        raise ReadEnough.new if result.size > (CrawlTopicLink.max_chunk_size(uri) * 1024)
      end
      Excon.get(uri.to_s, response_block: streamer, read_timeout: 20, headers: CrawlTopicLink.request_headers(uri))
      result

    rescue Excon::Errors::SocketError => ex
      return result if ex.socket_error.is_a?(ReadEnough)
      raise
    rescue ReadEnough
      result
    end

    def execute(args)
      raise Discourse::InvalidParameters.new(:topic_link_id) unless args[:topic_link_id].present?

      topic_link = TopicLink.find_by(id: args[:topic_link_id], internal: false, crawled_at: nil)
      return if topic_link.blank?

      topic_embed = TopicEmbed.where(embed_url: topic_link.url).includes(:topic).references(:topic).first
      if topic_embed && topic_embed.topic
        TopicLink.where(id: topic_link.id).update_all(['title = ?, crawled_at = CURRENT_TIMESTAMP', topic_embed.topic.title[0..255]])
        return
      end

      begin
        crawled = false

        if topic_link.url =~ /\.(jpg|gif|png)$/
          uri = URI(topic_link.url)
          filename = File.basename(uri.path)
          crawled = (TopicLink.where(id: topic_link.id).update_all(["title = ?, crawled_at = CURRENT_TIMESTAMP", filename]) == 1)
        end

        unless crawled
          result = CrawlTopicLink.fetch_beginning(topic_link.url)
          doc = Nokogiri::HTML(result)
          if doc
            title = doc.at('title').try(:inner_text)
            if title.present?
              title.gsub!(/\n/, ' ')
              title.gsub!(/ +/, ' ')
              title.strip!
              if title.present?
                crawled = (TopicLink.where(id: topic_link.id).update_all(['title = ?, crawled_at = CURRENT_TIMESTAMP', title[0..254]]) == 1)
              end
            end
          end
        end
      rescue Exception
      ensure
        TopicLink.where(id: topic_link.id).update_all('crawled_at = CURRENT_TIMESTAMP') if !crawled && topic_link.present?
      end
    end

  end
end
