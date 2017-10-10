class PostAlertObserver < ActiveRecord::Observer
  observe :post_action, :post_revision

  def alerter
    @alerter ||= PostAlerter.new
  end

  def after_save(model)
    method_name = callback_for('after_save', model)
    #nodyna <send-401> <SD COMPLEX (change-prone variables)>
    send(method_name, model) if respond_to?(method_name)
  end

  def after_create(model)
    method_name = callback_for('after_create', model)
    #nodyna <send-402> <SD COMPLEX (change-prone variables)>
    send(method_name, model) if respond_to?(method_name)
  end

  def after_save_post_action(post_action)
    return if post_action.deleted_at.blank?
    Notification.where(post_action_id: post_action.id).each(&:destroy)
  end

  def after_create_post_action(post_action)
    return unless post_action.is_like?

    post = post_action.post
    return if post_action.user.blank?

    alerter.create_notification(
      post.user,
      Notification.types[:liked],
      post,
      display_username: post_action.user.username,
      post_action_id: post_action.id,
      user_id: post_action.user_id
    )
  end

  def after_create_post_revision(post_revision)
    post = post_revision.post

    return unless post
    return if post_revision.user.blank?
    return if post_revision.user_id == post.user_id
    return if post.topic.private_message?
    return if SiteSetting.disable_edit_notifications && post_revision.user_id == Discourse::SYSTEM_USER_ID

    alerter.create_notification(
      post.user,
      Notification.types[:edited],
      post,
      display_username: post_revision.user.username,
      acting_user_id: post_revision.try(:user_id)
    )
  end

  protected

    def callback_for(action, model)
      "#{action}_#{model.class.name.underscore.gsub(/.+\//, '')}"
    end

end
