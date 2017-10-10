module ActiveJob
  module QueueAdapters
    class TestAdapter
      delegate :name, to: :class
      attr_accessor(:perform_enqueued_jobs, :perform_enqueued_at_jobs)
      attr_writer(:enqueued_jobs, :performed_jobs)

      def initialize
        self.perform_enqueued_jobs = false
        self.perform_enqueued_at_jobs = false
      end

      def enqueued_jobs
        @enqueued_jobs ||= []
      end

      def performed_jobs
        @performed_jobs ||= []
      end

      def enqueue(job) #:nodoc:
        if perform_enqueued_jobs
          performed_jobs << {job: job.class, args: job.serialize['arguments'], queue: job.queue_name}
          Base.execute job.serialize
        else
          enqueued_jobs << {job: job.class, args: job.serialize['arguments'], queue: job.queue_name}
        end
      end

      def enqueue_at(job, timestamp) #:nodoc:
        if perform_enqueued_at_jobs
          performed_jobs << {job: job.class, args: job.serialize['arguments'], queue: job.queue_name, at: timestamp}
          Base.execute job.serialize
        else
          enqueued_jobs << {job: job.class, args: job.serialize['arguments'], queue: job.queue_name, at: timestamp}
        end
      end
    end
  end
end
