
class Postzord::Receiver::Public < Postzord::Receiver

  attr_accessor :salmon, :author

  def initialize(xml)
    @salmon = Salmon::Slap.from_xml(xml)
    @author = Webfinger.new(@salmon.author_id).fetch
  end

  def verified_signature?
    @salmon.verified_for_key?(@author.public_key)
  end

  def receive!
    return unless verified_signature?

    parse_and_receive(@salmon.parsed_data)

    logger.info "received a #{@object.inspect}"
    if @object.is_a?(SignedRetraction) # feels like a hack
      self.recipient_user_ids.each do |user_id|
        user = User.where(id: user_id).first
        @object.perform user if user
      end
    elsif @object.respond_to?(:relayable?)
      receive_relayable
    elsif @object.is_a?(AccountDeletion)
    else
      Workers::ReceiveLocalBatch.perform_async(@object.class.to_s, @object.id, self.recipient_user_ids)
    end
  end

  def receive_relayable
    if @object.parent_author.local?
      @object.receive(@object.parent_author.owner, @author)
    end
    receiver = Postzord::Receiver::LocalBatch.new(@object, self.recipient_user_ids)
    receiver.notify_users
  end

  def parse_and_receive(xml)
    @object = Diaspora::Parser.from_xml(xml)

    logger.info "starting public receive from person:#{@author.guid}"

    validate_object
    receive_object
  end

  def receive_object
    if @object.respond_to?(:receive_public)
      @object.receive_public
    elsif @object.respond_to?(:save!)
      @object.save!
    end
  end

  def recipient_user_ids
    User.all_sharing_with_person(@author).pluck('users.id')
  end

  def xml_author
    if @object.respond_to?(:relayable?)
      @object.parent_author.local? ? @object.diaspora_handle : @object.parent_diaspora_handle
    else
      @object.diaspora_handle
    end
  end

  private


  def validate_object
    raise Diaspora::XMLNotParseable if @object.nil?
    raise Diaspora::NonPublic if object_can_be_public_and_it_is_not?
    raise Diaspora::RelayableObjectWithoutParent if relayable_without_parent?
    raise Diaspora::AuthorXMLAuthorMismatch if author_does_not_match_xml_author?
  end

  def account_deletion_is_from_author
    return true unless @object.is_a?(AccountDeletion)
    return false if @object.diaspora_handle != @author.diaspora_handle
    return true
  end

  def object_can_be_public_and_it_is_not?
    @object.respond_to?(:public) && !@object.public?
  end
end
