
module Workers
  class QueueUsersForRemoval < Base
    include Sidetiq::Schedulable
    
    sidekiq_options queue: :maintenance
    
    recurrence { daily }
    
    def perform
      if AppConfig.settings.maintenance.remove_old_users.enable?
        users = User.where("last_seen < ? and locked_at is null and remove_after is null", 
          Time.now - (AppConfig.settings.maintenance.remove_old_users.after_days.to_i).days)
          .order(:last_seen)
          .limit(AppConfig.settings.maintenance.remove_old_users.limit_removals_to_per_day)

        users.each do |user|
          if user.sign_in_count > 0
            remove_at = Time.now + AppConfig.settings.maintenance.remove_old_users.warn_days.to_i.days
          else
            remove_at = Time.now
          end
          user.flag_for_removal(remove_at)
          if user.sign_in_count > 0
            Maintenance.account_removal_warning(user).deliver_now
          end
          Workers::RemoveOldUser.perform_in(remove_at+1.day, user.id)
        end
      end
    end
  end 
end
