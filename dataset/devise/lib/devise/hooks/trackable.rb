Warden::Manager.after_set_user except: :fetch do |record, warden, options|
  if record.respond_to?(:update_tracked_fields!) && warden.authenticated?(options[:scope]) && !warden.request.env['devise.skip_trackable']
    record.update_tracked_fields!(warden.request)
  end
end
