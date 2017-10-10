require 'sidekiq'

module ActiveJob
  module QueueAdapters
    class SidekiqAdapter
      class << self
        def enqueue(job) #:nodoc:
          Sidekiq::Client.push \
            'class' => JobWrapper,
            'wrapped' => job.class.to_s,
            'queue' => job.queue_name,
            'args'  => [ job.serialize ]
        end

        def enqueue_at(job, timestamp) #:nodoc:
          Sidekiq::Client.push \
            'class' => JobWrapper,
            'wrapped' => job.class.to_s,
            'queue' => job.queue_name,
            'args'  => [ job.serialize ],
            'at'    => timestamp
        end
      end

      class JobWrapper #:nodoc:
        include Sidekiq::Worker

        def perform(job_data)
          Base.execute job_data
        end
      end
    end
  end
end
