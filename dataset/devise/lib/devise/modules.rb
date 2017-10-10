require 'active_support/core_ext/object/with_options'

Devise.with_options model: true do |d|
  d.with_options strategy: true do |s|
    routes = [nil, :new, :destroy]
    s.add_module :database_authenticatable, controller: :sessions, route: { session: routes }
    s.add_module :rememberable, no_input: true
  end

  d.add_module :omniauthable, controller: :omniauth_callbacks,  route: :omniauth_callback

  routes = [nil, :new, :edit]
  d.add_module :recoverable,  controller: :passwords,     route: { password: routes }
  d.add_module :registerable, controller: :registrations, route: { registration: (routes << :cancel) }
  d.add_module :validatable

  routes = [nil, :new]
  d.add_module :confirmable,  controller: :confirmations, route: { confirmation: routes }
  d.add_module :lockable,     controller: :unlocks,       route: { unlock: routes }
  d.add_module :timeoutable

  d.add_module :trackable
end
