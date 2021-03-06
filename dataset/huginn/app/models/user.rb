class User < ActiveRecord::Base
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable, :lockable,
         :omniauthable

  INVITATION_CODES = [ENV['INVITATION_CODE'] || 'try-huginn']

  attr_accessor :login

  ACCESSIBLE_ATTRIBUTES = [ :email, :username, :login, :password, :password_confirmation, :remember_me, :invitation_code ]

  attr_accessible *ACCESSIBLE_ATTRIBUTES
  attr_accessible *(ACCESSIBLE_ATTRIBUTES + [:admin]), :as => :admin

  validates_presence_of :username
  validates_uniqueness_of :username
  validates_format_of :username, :with => /\A[a-zA-Z0-9_-]{3,15}\Z/, :message => "can only contain letters, numbers, underscores, and dashes, and must be between 3 and 15 characters in length."
  validates_inclusion_of :invitation_code, :on => :create, :in => INVITATION_CODES, :message => "is not valid", if: ->{ User.using_invitation_code? }

  has_many :user_credentials, :dependent => :destroy, :inverse_of => :user
  has_many :events, -> { order("events.created_at desc") }, :dependent => :delete_all, :inverse_of => :user
  has_many :agents, -> { order("agents.created_at desc") }, :dependent => :destroy, :inverse_of => :user
  has_many :logs, :through => :agents, :class_name => "AgentLog"
  has_many :scenarios, :inverse_of => :user, :dependent => :destroy
  has_many :services, -> { by_name('asc') }, :dependent => :destroy

  def available_services
    Service.available_to_user(self).by_name
  end

  def self.find_first_by_auth_conditions(warden_conditions)
    conditions = warden_conditions.dup
    if login = conditions.delete(:login)
      where(conditions).where(["lower(username) = :value OR lower(email) = :value", { :value => login.downcase }]).first
    else
      where(conditions).first
    end
  end

  def self.using_invitation_code?
    ENV['SKIP_INVITATION_CODE'] != 'true'
  end
end
