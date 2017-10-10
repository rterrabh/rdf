class PostWordpressSerializer < BasicPostSerializer
  attributes :post_number

  def avatar_template
    if object.user
      UrlHelper.absolute object.user.avatar_template
    else
      nil
    end
  end

end
