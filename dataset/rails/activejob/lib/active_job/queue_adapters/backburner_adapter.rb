require 'backburner'

module ActiveJob
  module QueueAdapters
    class BackburnerAdapter
      class << self
        def enqueue(job) #:nodoc:
          Backburner::Worker.enqueue JobWrapper, [ job.serialize ], queue: job.queue_name
        end

        def enqueue_at(job, timestamp) #:nodoc:
          delay = timestamp - Time.current.to_f
          Backburner::Worker.enqueue JobWrapper, [ job.serialize ], queue: job.queue_name, delay: delay
        end
      end

      class JobWrapper #:nodoc:
        class << self
          def perform(job_data)
            Base.execute job_data
          end
        end
      end
    end
  end
end
