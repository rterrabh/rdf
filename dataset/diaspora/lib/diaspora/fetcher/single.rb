module Diaspora
  module Fetcher
    module Single
      module_function

      def find_or_fetch_from_remote guid, author_id
        post = Post.where(guid: guid).first
        return post if post

        post_author = Webfinger.new(author_id).fetch
        post_author.save! unless post_author.persisted?

        if fetched_post = fetch_post(post_author, guid)
          yield fetched_post, post_author if block_given?
          raise Diaspora::PostNotFetchable unless fetched_post.save
        end

        fetched_post
      end

      def fetch_post author, guid
        url = URI.join(author.url, "/p/#{guid}.xml")
        response = Faraday.get(url)
        raise Diaspora::PostNotFetchable if response.status == 404 # Old pod, Friendika, deleted
        raise "Failed to get #{url}" unless response.success? # Other error, N/A for example
        Diaspora::Parser.from_xml(response.body)
      end
    end
  end
end
