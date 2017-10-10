
module GettingStartedHelper
  def has_completed_getting_started?
    current_user.getting_started == false
  end

  def tag_link(tag_name)
    if tag_followed?(tag_name)
      link_to "##{tag_name}", tag_followings_path(tag_name), :method => :delete, :class => "featured_tag followed"
    else
      link_to "##{tag_name}", tag_tag_followings_path(tag_name), :method => :post, :class => "featured_tag"
    end
  end

  def tag_followed?(tag_name)
    tags.detect{|t| t.name == tag_name}
  end
end
