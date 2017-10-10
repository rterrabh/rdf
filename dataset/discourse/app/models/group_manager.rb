class GroupManager < ActiveRecord::Base
  belongs_to :group
  belongs_to :manager, class_name: "User", foreign_key: :user_id
end

