
class AspectVisibility < ActiveRecord::Base

  belongs_to :aspect
  validates :aspect, :presence => true

  belongs_to :shareable, :polymorphic => true
  validates :shareable, :presence => true

end
