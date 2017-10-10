require 'que'

module ActiveJob
  module QueueAdapters
    class QueAdapter
      class << self
        def enqueue(job) #:nodoc:
          JobWrapper.enqueue job.serialize, queue: job.queue_name
        end

        def enqueue_at(job, timestamp) #:nodoc:
          JobWrapper.enqueue job.serialize, queue: job.queue_name, run_at: Time.at(timestamp)
        end
      end

      class JobWrapper < Que::Job #:nodoc:
        def run(job_data)
          Base.execute job_data
        end
      end
    end
  end
end
