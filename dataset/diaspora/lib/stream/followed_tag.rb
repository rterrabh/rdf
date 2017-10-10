
class Stream::FollowedTag < Stream::Base

  def link(opts={})
    Rails.application.routes.url_helpers.tag_followings_path(opts)
  end

  def title
    I18n.t('streams.followed_tag.title')
  end

  def posts
    @posts ||= StatusMessage.user_tag_stream(user, tag_ids)
  end

  def contacts_title
    I18n.translate('streams.followed_tag.contacts_title')
  end

  private

  def tag_string
    @tag_string ||= tags.join(', '){|tag| tag.name}.to_s
  end

  def tag_ids
    tags.map{|x| x.id}
  end

  def tags
    @tags = user.followed_tags
  end
end
