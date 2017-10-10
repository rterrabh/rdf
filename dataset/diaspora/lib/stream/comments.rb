
class Stream::Comments < Stream::Base
  def link(opts={})
    Rails.application.routes.url_helpers.comment_stream_path(opts)
  end

  def title
    I18n.translate("streams.comment_stream.title")
  end

  def posts
    @posts ||= EvilQuery::CommentedPosts.new(user).posts
  end

  def contacts_title
    I18n.translate('streams.comment_stream.contacts_title')
  end
end
