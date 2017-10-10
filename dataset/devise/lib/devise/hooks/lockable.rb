Warden::Manager.after_set_user except: :fetch do |record, warden, options|
  if record.respond_to?(:failed_attempts) && warden.authenticated?(options[:scope])
    record.update_attribute(:failed_attempts, 0) unless record.failed_attempts.to_i.zero?
  end
end
