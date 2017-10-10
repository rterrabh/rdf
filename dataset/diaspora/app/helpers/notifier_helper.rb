module NotifierHelper

  def post_message(post, opts={})
    if post.respond_to? :message
      post.message.plain_text_without_markdown
    else
      I18n.translate 'notifier.a_post_you_shared'
    end
  end

  def comment_message(comment, opts={})
    if comment.post.public?
      comment.message.plain_text_without_markdown
    else
      I18n.translate 'notifier.a_limited_post_comment'
    end
  end
end
