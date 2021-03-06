require_dependency 'score_calculator'

module Jobs

  class Weekly < Jobs::Scheduled
    every 1.week

    def execute(args)
      Post.calculate_avg_time
      Topic.calculate_avg_time
      ScoreCalculator.new.calculate
      Draft.cleanup!
    end
  end
end
