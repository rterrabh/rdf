class CategoryGroup < ActiveRecord::Base
  belongs_to :category
  belongs_to :group

  def self.permission_types
    @permission_types ||= Enum.new(:full, :create_post, :readonly)
  end

end

