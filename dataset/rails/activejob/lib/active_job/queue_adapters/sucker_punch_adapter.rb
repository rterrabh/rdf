require 'sucker_punch'

module ActiveJob
  module QueueAdapters
    class SuckerPunchAdapter
      class << self
        def enqueue(job) #:nodoc:
          JobWrapper.new.async.perform job.serialize
        end

        def enqueue_at(job, timestamp) #:nodoc:
          raise NotImplementedError
        end
      end

      class JobWrapper #:nodoc:
        include SuckerPunch::Job

        def perform(job_data)
          Base.execute job_data
        end
      end
    end
  end
end
