module Jobs

  class EnqueueDigestEmails < Jobs::Scheduled
    every 6.hours

    def execute(args)
      unless SiteSetting.disable_digest_emails?
        target_user_ids.each do |user_id|
          Jobs.enqueue(:user_email, type: :digest, user_id: user_id)
        end
      end
    end

    def target_user_ids
      query = User.real
                  .where(email_digests: true, active: true)
                  .not_suspended
                  .where("COALESCE(last_emailed_at, '2010-01-01') <= CURRENT_TIMESTAMP - ('1 DAY'::INTERVAL * digest_after_days)")
                  .where("(COALESCE(last_seen_at, '2010-01-01') <= CURRENT_TIMESTAMP - ('1 DAY'::INTERVAL * digest_after_days)) AND
                           COALESCE(last_seen_at, '2010-01-01') >= CURRENT_TIMESTAMP - ('1 DAY'::INTERVAL * #{SiteSetting.suppress_digest_email_after_days})")

      if SiteSetting.must_approve_users?
        query = query.where("approved OR moderator OR admin")
      end

      query.pluck(:id)
    end

  end

end
