
module Workers
  class RemoveOldUser < Base
    sidekiq_options queue: :maintenance
    
    def safe_remove_after
      Time.now-
        (AppConfig.settings.maintenance.remove_old_users.after_days.to_i).days-
        (AppConfig.settings.maintenance.remove_old_users.warn_days.to_i).days
    end
    
    def perform(user_id)
      if AppConfig.settings.maintenance.remove_old_users.enable?
        user = User.find(user_id)
        if user.remove_after < Time.now and user.last_seen < self.safe_remove_after
          user.close_account!
        end
      end
    end
  end 
end
