module Jobs

  class CleanUpUnmatchedIPs < Jobs::Scheduled
    every 1.day

    def execute(args)
      ScreenedIpAddress.roll_up

      last_match_threshold = SiteSetting.max_age_unmatched_ips.days.ago

      ScreenedIpAddress.where(action_type: ScreenedIpAddress.actions[:block])
                       .where("last_match_at < ? OR (last_match_at IS NULL AND created_at < ?)", last_match_threshold, last_match_threshold)
                       .destroy_all
    end

  end

end
