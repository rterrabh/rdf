
class Invitation < ActiveRecord::Base

  belongs_to :sender, :class_name => 'User'
  belongs_to :recipient, :class_name => 'User'
  belongs_to :aspect

  before_validation :set_email_as_default_service

  validates :identifier, :presence => true
  validates :service, :presence => true
  validate :valid_identifier?
  validate :recipient_not_on_pod?
  validates_presence_of :sender, :aspect, :unless => :admin?
  validate :ensure_not_inviting_self, :on => :create, :unless => :admin?
  validate :sender_owns_aspect?, :unless => :admin?
  validates_uniqueness_of :sender_id, :scope => [:identifier, :service], :unless => :admin?


  def self.batch_invite(emails, opts)

    users_on_pod = User.where(:email => emails, :invitation_token => nil)

    users_on_pod.each{|u| opts[:sender].share_with(u.person, opts[:aspect])}

    emails.map! do |e|
      user = users_on_pod.find{|u| u.email == e}
      Invitation.create(opts.merge(:identifier => e, :recipient => user))
    end
    emails
  end
  
  
  def identifier=(ident)
    ident.downcase! if ident
    super
  end

  def skip_email?
    !email_like_identifer
  end

  #nodyna <send-223> <not yet classified>
  def send!
    if email_like_identifer
      #nodyna <send-224> <not yet classified>
      EmailInviter.new(self.identifier, sender).send! 
    else
      puts "broken facebook invitation_token"
    end
    self
  end


  def convert_to_admin!
    self.admin = true
    self.sender = nil
    self.aspect = nil
    self.save
    self
  end
  def resend
    #nodyna <send-225> <not yet classified>
    self.send!
  end

  def recipient_identifier
    case self.service
    when 'email'
      self.identifier
    when'facebook'
      I18n.t('invitations.a_facebook_user')
    end
  end
  
  def email_like_identifer
    case self.service
    when 'email'
      self.identifier
    when 'facebook'
      false
    end
  end

  def set_email_as_default_service
    self.service ||= 'email'
  end

  def ensure_not_inviting_self
    if self.identifier == self.sender.email
      errors[:base] << 'You can not invite yourself.'
    end
  end  

  def sender_owns_aspect?
    if self.sender_id != self.aspect.user_id
      errors[:base] << 'You do not own that aspect.'
    end
  end


  def recipient_not_on_pod?
    return true if self.recipient.nil?
    if self.recipient.username?
      errors[:recipient] << "The user '#{self.identifier}' (#{self.recipient.diaspora_handle}) is already on this pod, so we sent them a share request"
    end
  end

  def valid_identifier?
    return false unless self.identifier
    if self.service == 'email'
      unless self.identifier.match(Devise.email_regexp)
        errors[:base] << 'invalid email'
      end
    end
  end
end
