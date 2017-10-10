class BarAbility
  include CanCan::Ability

  def initialize(user)
    user ||= Spree::User.new
    if user.has_spree_role? 'bar'
      can [:admin, :index, :show], Spree::Order
      can [:admin, :manage], Spree::Shipment
    end
  end
end
