class RelayableRetraction < SignedRetraction
  xml_name :relayable_retraction
  xml_attr :parent_author_signature

  attr_accessor :parent_author_signature

  delegate :parent, :parent_author, to: :target, allow_nil: true

  def signable_accessors
    super - ['parent_author_signature']
  end

  def self.build(sender, target)
    retraction = super
    retraction.parent_author_signature = retraction.sign_with_key(sender.encryption_key) if defined?(target.parent) && sender.person == target.parent.author
    retraction
  end

  def diaspora_handle
    self.sender_handle
  end

  def relayable?
    true
  end

  def perform receiving_user
    logger.debug "Performing relayable retraction for #{target_guid}"
    if not self.parent_author_signature.nil? or self.parent.author.remote?
      self.target.destroy
      logger.info "event=relayable_retraction status=complete target_type=#{target_type} guid=#{target_guid}"
    end
  end

  def receive(recipient, sender)
    if self.target.nil?
      logger.warn "event=retraction status=abort reason='no post found' sender=#{sender.diaspora_handle} " \
                  "target_guid=#{target_guid}"
      return
    elsif self.parent.author == recipient.person && self.target_author_signature_valid?
      self.parent_author_signature = self.sign_with_key(recipient.encryption_key)
      Postzord::Dispatcher.build(recipient, self).post
      self.perform(recipient)
    elsif self.parent_author_signature_valid?
      self.perform(recipient)
    else
      logger.warn "event=receive status=abort reason='object signature not valid' " \
                  "recipient=#{recipient.diaspora_handle} sender=#{parent.author.diaspora_handle} " \
                  "payload_type=#{self.class} parent_id=#{parent.id}"
      return
    end
    self
  end

  def parent_author_signature_valid?
    verify_signature(self.parent_author_signature, self.parent.author)
  end

  def parent_diaspora_handle
    target.author.diaspora_handle
  end
end
