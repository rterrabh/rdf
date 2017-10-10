Warden::Manager.before_logout do |record, warden, options|
  if record.respond_to?(:forget_me!)
    Devise::Hooks::Proxy.new(warden).forget_me(record)
  end
end
