class UserField < ActiveRecord::Base
  validates_presence_of :name, :description, :field_type
  has_many :user_field_options, dependent: :destroy
  accepts_nested_attributes_for :user_field_options

  def self.max_length
    2048
  end
end

