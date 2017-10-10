module Jobs

  class Heartbeat < Jobs::Scheduled
    every 3.minute

    def execute(args)
      Jobs.enqueue(:run_heartbeat, {})
    end
  end
end
