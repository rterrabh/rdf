Warden::Manager.after_set_user do |record, warden, options|
  if record && record.respond_to?(:active_for_authentication?) && !record.active_for_authentication?
    scope = options[:scope]
    warden.logout(scope)
    throw :warden, scope: scope, message: record.inactive_message
  end
end
