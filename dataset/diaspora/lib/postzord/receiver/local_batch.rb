
class Postzord::Receiver::LocalBatch < Postzord::Receiver

  attr_reader :object, :recipient_user_ids, :users

  def initialize(object, recipient_user_ids)
    @object = object
    @recipient_user_ids = recipient_user_ids
    @users = User.where(:id => @recipient_user_ids)

  end

  def receive!
    logger.info "receiving local batch for #{@object.inspect}"
    if @object.respond_to?(:relayable?)
      receive_relayable
    else
      create_share_visibilities
    end
    notify_mentioned_users if @object.respond_to?(:mentions)

    notify_users

    logger.info "receiving local batch completed for #{@object.inspect}"
  end

  def receive_relayable
    if @object.parent_author.local?
      @object.receive(@object.parent_author.owner)
    end
  end

  def create_share_visibilities
    contacts_ids = Contact.connection.select_values(Contact.where(:user_id => @recipient_user_ids, :person_id => @object.author_id).select("id").to_sql)
    ShareVisibility.batch_import(contacts_ids, object)
  end

  def notify_mentioned_users
    @object.mentions.each do |mention|
      mention.notify_recipient
    end
  end

  def notify_users
    return unless @object.respond_to?(:notification_type)
    @users.find_each do |user|
      Notification.notify(user, @object, @object.author)
    end
  end
end
