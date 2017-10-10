require 'shared_admin'

class Admin
  include Mongoid::Document
  include Shim
  include SharedAdmin

  field :email,              type: String
  field :encrypted_password, type: String

  field :reset_password_token,   type: String
  field :reset_password_sent_at, type: Time

  field :remember_created_at, type: Time

  field :confirmation_token,   type: String
  field :confirmed_at,         type: Time
  field :confirmation_sent_at, type: Time
  field :unconfirmed_email,    type: String # Only if using reconfirmable

  field :locked_at, type: Time

  field :active, type: Boolean, default: false
end
