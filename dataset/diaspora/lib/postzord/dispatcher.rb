

class Postzord::Dispatcher
  include Diaspora::Logging

  require 'postzord/dispatcher/private'
  require 'postzord/dispatcher/public'

  attr_reader :sender, :object, :xml, :subscribers, :opts

  def initialize(user, object, opts={})
    @sender = user
    @object = object
    @xml = @object.to_diaspora_xml
    @opts = opts

    additional_subscribers = opts[:additional_subscribers] || []
    @subscribers = subscribers_from_object | [*additional_subscribers]
  end

  def self.build(user, object, opts={})
    unless object.respond_to? :to_diaspora_xml
      raise 'This object does not respond_to? to_diaspora xml.  Try including Diaspora::Federated::Base into your object'
    end

    if self.object_should_be_processed_as_public?(object)
      Postzord::Dispatcher::Public.new(user, object, opts)
    else
      Postzord::Dispatcher::Private.new(user, object, opts)
    end
  end

  def self.defer_build_and_post(user, object, opts={})
    opts[:additional_subscribers] ||= []
    if opts[:additional_subscribers].present?
      opts[:additional_subscribers] = [*opts[:additional_subscribers]].map(&:id)
    end

    if opts[:to].present?
      opts[:to] = [*opts[:to]].map {|e| e.respond_to?(:id) ? e.id : e }
    end

    Workers::DeferredDispatch.perform_async(user.id, object.class.to_s, object.id, opts)
  end

  def self.object_should_be_processed_as_public?(object)
    if object.respond_to?(:public?) && object.public?
      true
    else
      false
    end
  end

  def post
    self.deliver_to_services(@opts[:url], @opts[:services] || [])
    self.post_to_subscribers if @subscribers.present?
    self.process_after_dispatch_hooks
    @object
  end

  protected

  def process_after_dispatch_hooks
    @object.after_dispatch(@sender)
    @object
  end

  def post_to_subscribers
    remote_people, local_people = @subscribers.partition{ |person| person.owner_id.nil? }

    if @object.respond_to?(:relayable?) && @sender.owns?(@object.parent)
      self.notify_local_users(local_people)
    else
      self.deliver_to_local(local_people)
    end

    self.deliver_to_remote(remote_people)
  end

  def subscribers_from_object
    @object.subscribers(@sender)
  end

  def fetch_local_users(people)
    return [] if people.blank?
    user_ids = people.map{|x| x.owner_id }
    User.where(:id => user_ids)
  end

  def deliver_to_remote(remote_people)
    return if remote_people.blank?
    queue_remote_delivery_job(remote_people)
  end

  def queue_remote_delivery_job(remote_people)
    Workers::HttpMulti.perform_async(
      @sender.id,
      Base64.strict_encode64(@object.to_diaspora_xml),
      remote_people.map{|p| p.id},
      self.class.to_s
    )
  end

  def deliver_to_local(people)
    return if people.blank? || @object.is_a?(Profile)
    if @object.respond_to?(:persisted?) && !@object.is_a?(Conversation)
      batch_deliver_to_local(people)
    else
      people.each do |person|
        logger.info "event=push route=local sender=#{@sender.diaspora_handle} recipient=#{person.diaspora_handle} " \
                    "payload_type=#{@object.class}"
        Workers::Receive.perform_async(person.owner_id, @xml, @sender.person_id)
      end
    end
  end

  def batch_deliver_to_local(people)
    ids = people.map{ |p| p.owner_id }
    Workers::ReceiveLocalBatch.perform_async(@object.class.to_s, @object.id, ids)
    logger.info "event=push route=local sender=#{@sender.diaspora_handle} recipients=#{ids.join(',')} " \
                "payload_type=#{@object.class}"
  end

  def deliver_to_hub
    logger.debug "event=post_to_service type=pubsub sender_handle=#{@sender.diaspora_handle}"
    Workers::PublishToHub.perform_async(@sender.atom_url)
  end

  def deliver_to_services(url, services)
    if @object.respond_to?(:public) && @object.public
      deliver_to_hub
    end
    services.each do |service|
      if @object.instance_of?(StatusMessage)
        Workers::PostToService.perform_async(service.id, @object.id, url)
      end
      if @object.instance_of?(SignedRetraction)
        Workers::DeletePostFromService.perform_async(service.id, @object.target.id)
      end
    end
  end

  def notify_local_users(local_people)
    local_users = fetch_local_users(local_people)
    self.notify_users(local_users)
  end

  def notify_users(users)
    return unless users.present? && @object.respond_to?(:persisted?)

    Workers::NotifyLocalUsers.perform_async(users.map(&:id), @object.class.to_s, @object.id, @object.author.id)
  end
end

