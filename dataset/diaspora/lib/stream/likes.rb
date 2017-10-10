
class Stream::Likes < Stream::Base
  def link(opts={})
    Rails.application.routes.url_helpers.like_stream_path(opts)
  end

  def title
    I18n.translate("streams.like_stream.title")
  end

  def posts
    @posts ||= EvilQuery::LikedPosts.new(user).posts
  end

  def contacts_title
    I18n.translate('streams.like_stream.contacts_title')
  end
end
