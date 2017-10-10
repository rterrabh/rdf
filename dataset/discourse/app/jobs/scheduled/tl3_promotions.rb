module Jobs

  class Tl3Promotions < Jobs::Scheduled
    daily at: 4.hours

    def execute(args)
      demoted_user_ids = []
      User.real.where(trust_level: TrustLevel[3], trust_level_locked: false).find_each do |u|
        next if u.on_tl3_grace_period?

        if Promotion.tl3_lost?(u)
          demoted_user_ids << u.id
          Promotion.new(u).change_trust_level!(TrustLevel[2])
        end
      end

      User.real.where(trust_level: TrustLevel[2],
                      trust_level_locked: false)
               .where.not(id: demoted_user_ids).find_each do |u|
        Promotion.new(u).review_tl2
      end
    end
  end

end
