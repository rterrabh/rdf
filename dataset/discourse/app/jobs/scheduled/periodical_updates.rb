require_dependency 'score_calculator'

module Jobs

  class PeriodicalUpdates < Jobs::Scheduled
    every 15.minutes

    def execute(args)
      CategoryFeaturedTopic.feature_topics

      ScoreCalculator.new.calculate(1.day.ago)

      Topic.auto_close

      unless UserAvatar.where("last_gravatar_download_attempt IS NULL").limit(1).first
        problems = Post.rebake_old(250)
        problems.each do |hash|
          post_id = hash[:post].id
          Discourse.handle_job_exception(hash[:ex], error_context(args, "Rebaking post id #{post_id}", post_id: post_id))
        end
      end

      problems = UserProfile.rebake_old(250)
      problems.each do |hash|
        user_id = hash[:profile].user_id
        Discourse.handle_job_exception(hash[:ex], error_context(args, "Rebaking user id #{user_id}", user_id: user_id))
      end
    end

  end

end
