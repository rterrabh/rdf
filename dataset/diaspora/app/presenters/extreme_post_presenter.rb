class ExtremePostPresenter
  def initialize(post, current_user)
    @post = post
    @current_user = current_user
  end

  def as_json(options={})
    post = PostPresenter.new(@post, @current_user)
    interactions = PostInteractionPresenter.new(@post, @current_user)
    post.as_json.merge!(:interactions => interactions.as_json)
  end
end
