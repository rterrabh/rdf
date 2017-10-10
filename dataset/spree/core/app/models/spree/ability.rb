require 'cancan'
module Spree
  class Ability
    include CanCan::Ability

    class_attribute :abilities
    self.abilities = Set.new

    def self.register_ability(ability)
      self.abilities.add(ability)
    end

    def self.remove_ability(ability)
      self.abilities.delete(ability)
    end

    def initialize(user)
      self.clear_aliased_actions

      alias_action :delete, to: :destroy
      alias_action :edit, to: :update
      alias_action :new, to: :create
      alias_action :new_action, to: :create
      alias_action :show, to: :read
      alias_action :index, :read, to: :display
      alias_action :create, :update, :destroy, to: :modify

      user ||= Spree.user_class.new

      if user.respond_to?(:has_spree_role?) && user.has_spree_role?('admin')
        can :manage, :all
      else
        can :display, Country
        can :display, OptionType
        can :display, OptionValue
        can :create, Order
        can [:read, :update], Order do |order, token|
          order.user == user || order.guest_token && token == order.guest_token
        end
        can :display, CreditCard, user_id: user.id
        can :display, Product
        can :display, ProductProperty
        can :display, Property
        can :create, Spree.user_class
        can [:read, :update, :destroy], Spree.user_class, id: user.id
        can :display, State
        can :display, Taxon
        can :display, Taxonomy
        can :display, Variant
        can :display, Zone
      end

      Ability.abilities.each do |clazz|
        #nodyna <send-2526> <SD EASY (array)>
        ability = clazz.send(:new, user)
        #nodyna <send-2527> <SD EASY (array)>
        @rules = rules + ability.send(:rules)
      end

      cannot [:update, :destroy], Role, name: ['admin']
    end
  end
end
