class ComposerMessagesFinder

  def initialize(user, details)
    @user = user
    @details = details
  end

  def find
    check_reviving_old_topic ||
    check_education_message ||
    check_new_user_many_replies ||
    check_avatar_notification ||
    check_sequential_replies ||
    check_dominating_topic
  end

  def check_education_message
    if creating_topic?
      count = @user.created_topic_count
      education_key = :education_new_topic
    else
      count = @user.post_count
      education_key = :education_new_reply
    end

    if count < SiteSetting.educate_until_posts
      education_posts_text = I18n.t('education.until_posts', count: SiteSetting.educate_until_posts)
      return {
        templateName: 'composer/education',
        wait_for_typing: true,
        body: PrettyText.cook(SiteText.text_for(education_key, education_posts_text: education_posts_text))
      }
    end

    nil
  end

  def check_new_user_many_replies
    return unless replying? && @user.posted_too_much_in_topic?(@details[:topic_id])

    {
      templateName: 'composer/education',
      body: PrettyText.cook(I18n.t('education.too_many_replies', newuser_max_replies_per_topic: SiteSetting.newuser_max_replies_per_topic))
    }
  end

  def check_avatar_notification

    return unless @user.has_trust_level?(TrustLevel[1])

    return if @user.uploaded_avatar_id || UserHistory.exists_for_user?(@user, :notified_about_avatar)

    UserHistory.create!(action: UserHistory.actions[:notified_about_avatar], target_user_id: @user.id )

    {
      templateName: 'composer/education',
      body: PrettyText.cook(I18n.t('education.avatar', profile_path: "/users/#{@user.username_lower}"))
    }
  end

  def check_sequential_replies

    return unless replying? && @details[:topic_id] &&

                  (@user.post_count >= SiteSetting.educate_until_posts) &&

                  !UserHistory.exists_for_user?(@user, :notified_about_sequential_replies, topic_id: @details[:topic_id])

    recent_posts_user_ids = Post.where(topic_id: @details[:topic_id])
                                .where("created_at > ?", 1.day.ago)
                                .order('created_at desc')
                                .limit(SiteSetting.sequential_replies_threshold)
                                .pluck(:user_id)

    return if recent_posts_user_ids.size != SiteSetting.sequential_replies_threshold ||
              recent_posts_user_ids.detect {|u| u != @user.id }

    UserHistory.create!(action: UserHistory.actions[:notified_about_sequential_replies],
                        target_user_id: @user.id,
                        topic_id: @details[:topic_id] )

    {
      templateName: 'composer/education',
      wait_for_typing: true,
      extraClass: 'urgent',
      body: PrettyText.cook(I18n.t('education.sequential_replies'))
    }
  end

  def check_dominating_topic

    return unless replying? &&
                  @details[:topic_id] &&
                  (@user.post_count >= SiteSetting.educate_until_posts) &&
                  !UserHistory.exists_for_user?(@user, :notified_about_dominating_topic, topic_id: @details[:topic_id])

    topic = Topic.find_by(id: @details[:topic_id])

    return if topic.blank? ||
              topic.user_id == @user.id ||
              topic.posts_count < SiteSetting.summary_posts_required ||
              topic.archetype == Archetype.private_message

    posts_by_user = @user.posts.where(topic_id: topic.id).count

    ratio = (posts_by_user.to_f / topic.posts_count.to_f)
    return if ratio < (SiteSetting.dominating_topic_minimum_percent.to_f / 100.0)

    UserHistory.create!(action: UserHistory.actions[:notified_about_dominating_topic],
                        target_user_id: @user.id,
                        topic_id: @details[:topic_id])

    {
      templateName: 'composer/education',
      wait_for_typing: true,
      extraClass: 'urgent',
      body: PrettyText.cook(I18n.t('education.dominating_topic', percent: (ratio * 100).round))
    }
  end

  def check_reviving_old_topic
    return unless @details[:topic_id]

    topic = Topic.find_by(id: @details[:topic_id])

    return unless replying?

    return if topic.nil? ||
              SiteSetting.warn_reviving_old_topic_age < 1 ||
              topic.last_posted_at.nil? ||
              topic.last_posted_at > SiteSetting.warn_reviving_old_topic_age.days.ago

    {
      templateName: 'composer/education',
      wait_for_typing: false,
      extraClass: 'urgent',
      body: PrettyText.cook(I18n.t('education.reviving_old_topic', days: (Time.zone.now - topic.last_posted_at).round / 1.day))
    }
  end

  private

    def creating_topic?
      @details[:composerAction] == "createTopic"
    end

    def replying?
      @details[:composerAction] == "reply"
    end

end
