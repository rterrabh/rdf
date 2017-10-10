module Jobs
  class ReindexSearch < Jobs::Scheduled
    every 1.day

    def execute(args)
      Search.rebuild_problem_posts
    end
  end
end
