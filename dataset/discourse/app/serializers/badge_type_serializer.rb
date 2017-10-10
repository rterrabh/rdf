class BadgeTypeSerializer < ApplicationSerializer
  attributes :id, :name, :sort_order

  def sort_order
    10 - object.id
  end
end
