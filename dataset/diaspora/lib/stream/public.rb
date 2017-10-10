
class Stream::Public < Stream::Base
  def link(opts={})
    Rails.application.routes.url_helpers.public_stream_path(opts)
  end

  def title
    I18n.translate("streams.public.title")
  end

  def posts
    @posts ||= Post.all_public
  end

  def contacts_title
    I18n.translate("streams.public.contacts_title")
  end

  def can_comment?(post)
    post.author.local?
  end
end
