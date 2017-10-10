module Jobs

  class CalculateAvgTime < Jobs::Scheduled
    every 1.day

    def execute(args)
      Post.calculate_avg_time(2.days.ago)
      Topic.calculate_avg_time(2.days.ago)
    end
  end
end
